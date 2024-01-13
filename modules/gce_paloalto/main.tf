resource "random_id" "seed" {
  byte_length = 2
}

data "google_compute_default_service_account" "compute_default_service_account" {
  project = var.project_id
}

resource "tls_private_key" "default" {
  count     = var.input.ssh_keys == null ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "private_key" {
  count = var.input.ssh_keys == null ? 1 : 0

  filename = "./config/test.key"
  content  = tls_private_key.default[0].private_key_pem
}

resource "google_storage_bucket_object" "init_cfg" {
  for_each = { for k, v in local.map : k => v if var.input.bootstrap_enabled }

  name = format("%s/config/init-cfg.txt", each.value.name)

  content = templatefile("${path.module}/templatefile/init-cfg.tmpl",
    {
      "redis-config" : try(var.input.regional_redis[each.value.region], null)
      "op-command-modes" : var.input.mgmt_interface_swap ? "mgmt-interface-swap" : ""
      "plugin-op-commands" : var.input.plugin_op_commands != null ? join(",", [for k, v in var.input.plugin_op_commands : format("%s:%s", k, v)]) : ""
    }
  )
  bucket = var.bucket_name
}

resource "google_compute_address" "external_addresses" {
  for_each     = { for k, v in merge(values(local.map).*.subnetworks...) : k => v if v.external_enabled }
  name         = format("%s-ext", each.key)
  project      = var.project_id
  region       = each.value.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
}

resource "google_compute_address" "internal_addresses" {
  for_each     = merge(values(local.map).*.subnetworks...)
  name         = format("%s-int", each.key)
  project      = var.project_id
  region       = each.value.region
  address_type = "INTERNAL"
  purpose      = "GCE_ENDPOINT"
  subnetwork   = format("%s-%s", each.value.subnetwork, local.random_id.hex)
}

resource "google_compute_instance" "instances" {
  for_each = local.map

  depends_on = [
    google_compute_address.internal_addresses,
    google_compute_address.external_addresses,
    google_storage_bucket_object.init_cfg,
  ]

  project = var.project_id

  name = each.value.name
  zone = each.value.zone

  boot_disk {
    auto_delete = true
    device_name = each.value.name

    initialize_params {
      image = var.image
      type  = "pd-ssd"
    }
  }

  tags = var.input.network_tags

  deletion_protection       = false
  can_ip_forward            = true
  enable_display            = false
  allow_stopping_for_update = true

  machine_type = each.value.machine_type
  # {foo:"bar",alpha:"bravo"}
  metadata = {
    mgmt-interface-swap                  = var.input.bootstrap_enabled ? null : (var.input.mgmt_interface_swap ? "enable" : null)
    vmseries-bootstrap-gce-storagebucket = var.input.bootstrap_enabled ? format("%s/%s", var.bucket_name, each.value.name) : null
    serial-port-enable                   = true
    ssh-keys                             = var.input.ssh_keys != null ? "admin:${var.input.ssh_keys}" : "admin:${tls_private_key.default[0].public_key_openssh}"
  }

  service_account {
    email  = each.value.service_account
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  dynamic "network_interface" {
    for_each = each.value.subnetworks
    content {
      network_ip         = google_compute_address.internal_addresses[network_interface.key].address
      subnetwork         = format("%s-%s", network_interface.value.subnetwork, local.random_id.hex)
      subnetwork_project = var.project_id
      dynamic "access_config" {
        for_each = network_interface.value.external_enabled ? [1] : []
        content {
          nat_ip = google_compute_address.external_addresses[network_interface.key].address
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [metadata["ssh-keys"]]
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/network_connectivity_spoke
resource "google_network_connectivity_spoke" "network_connectivity_spoke" {
  for_each = { for x in distinct(values(merge(values(local.map).*.subnetworks...))) : x.ncc_spoke => x if x.use_ncc_hub }

  project = var.project_id

  name = format("appliance-%s-%s-%s", random_id.seed.hex, each.key, local.random_id.hex)
  hub  = format("%s-%s", each.value.network_prefix, local.random_id.hex)

  location = each.value.region

  linked_router_appliance_instances {
    site_to_site_data_transfer = true
    dynamic "instances" {
      for_each = { for k1, v1 in google_compute_instance.instances : k1 => v1 if startswith(v1.zone, each.value.region) }
      content {
        virtual_machine = instances.value.self_link
        ip_address = [
          for k2, v2 in instances.value.network_interface : v2.network_ip if endswith(v2.subnetwork, format("%s-%s", each.value.subnetwork, local.random_id.hex))
        ][0]
      }
    }
  }

  depends_on = [
    google_compute_address.internal_addresses,
    google_compute_instance.instances,
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_peer
resource "google_compute_router_peer" "router_peer-nic0" {
  for_each = { for k, v in merge(values(local.map).*.subnetworks...) : k => v if v.use_ncc_hub }

  project = var.project_id

  name      = format("%s-peer0", each.key)
  router    = format("%s-%s", each.value.network_prefix, local.random_id.hex)
  region    = each.value.region
  interface = format("%s-%s-%s", var.config_map[each.value.network].prefix, format("nic%02d", 0), local.random_id.hex)

  peer_asn = try(
    var.input.regional_asn[each.value.region],
    var.input.shared_asn,
    var.default_asn,
  )

  router_appliance_instance = google_compute_instance.instances[regex("^(.*)-.", each.key)[0]].self_link
  peer_ip_address           = google_compute_address.internal_addresses[each.key].address
  advertised_route_priority = 100

  depends_on = [
    google_network_connectivity_spoke.network_connectivity_spoke,
    google_compute_address.internal_addresses,
    google_compute_instance.instances,
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_peer
resource "google_compute_router_peer" "router_peer-nic1" {
  for_each = { for k, v in merge(values(local.map).*.subnetworks...) : k => v if v.use_ncc_hub }

  project = var.project_id

  name      = format("%s-peer1", each.key)
  router    = format("%s-%s", each.value.network_prefix, local.random_id.hex)
  region    = each.value.region
  interface = format("%s-%s-%s", var.config_map[each.value.network].prefix, format("nic%02d", 1), local.random_id.hex)

  peer_asn = try(
    var.input.regional_asn[each.value.region],
    var.input.shared_asn,
    var.default_asn,
  )

  router_appliance_instance = google_compute_instance.instances[regex("^(.*)-.", each.key)[0]].self_link
  peer_ip_address           = google_compute_address.internal_addresses[each.key].address
  advertised_route_priority = 100

  depends_on = [
    google_compute_address.internal_addresses,
    google_compute_instance.instances,
    google_compute_router_peer.router_peer-nic0,
  ]
}

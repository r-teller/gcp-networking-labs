resource "random_id" "seed" {
  byte_length = 2
}


resource "google_compute_address" "addresses" {
  for_each     = merge(values(local.map).*.subnetworks...)
  name         = each.key
  project      = var.project_id
  region       = each.value.region
  address_type = "INTERNAL"
  purpose      = "GCE_ENDPOINT"
  subnetwork   = format("%s-%s", each.value.subnetwork, local.random_id.hex)
}

resource "google_compute_instance" "instances" {
  for_each = local.map

  depends_on = [
    google_compute_address.addresses
  ]

  project = var.project_id

  name = each.value.name
  zone = each.value.zone

  boot_disk {
    auto_delete = true
    device_name = each.value.name

    initialize_params {
      image = var.image
      size  = 10
      type  = "pd-standard"
    }

    mode = "READ_WRITE"
  }

  can_ip_forward      = true
  deletion_protection = false
  enable_display      = false

  machine_type = each.value.machine_type

  metadata = {
    serial-port-enable = "TRUE"
    # pubsub-subscription     = each.value.name
    # configuration_bucket_id = google_storage_bucket.bucket.name
    # configuration_object_id = each.value.bucket_object
  }

  dynamic "network_interface" {
    for_each = each.value.subnetworks
    content {
      network_ip         = google_compute_address.addresses[network_interface.key].address
      subnetwork         = format("%s-%s", network_interface.value.subnetwork, local.random_id.hex)
      subnetwork_project = var.project_id
    }
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
    provisioning_model  = "STANDARD"
  }

  service_account {
    email  = each.value.service_account
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
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
  #   hub      = each.value.ncc_hub_id
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
    google_compute_address.addresses,
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
  peer_ip_address           = google_compute_address.addresses[each.key].address
  advertised_route_priority = 100

  depends_on = [
    google_network_connectivity_spoke.network_connectivity_spoke,
    google_compute_address.addresses,
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
  peer_ip_address           = google_compute_address.addresses[each.key].address
  advertised_route_priority = 100

  depends_on = [
    google_compute_address.addresses,
    google_compute_instance.instances,
    google_compute_router_peer.router_peer-nic0,
  ]
}

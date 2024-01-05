resource "random_id" "core_wan-to-distro_lan-seed" {
  byte_length = 2
}


locals {
  core_wan-to-distro_lan-vyos = {
    ## if regional ASN exists it will be preferred over the shared ASN
    shared_asn = 65534
    regional_asn = {
      us-east4 : 4204100000,
      us-west1 : 4214100000,
      asia-southeast1 : 4224100000,
      europe-west3 : 4234100000,
    }
    prefix       = "core-wan-to-distro-lan"
    machine_type = "n2d-standard-2"
    zones = {
      "us-east4-a" = 1
      "us-west1-a" = 1
    }
    service_account = google_service_account.vyos_compute_sa.email
    interfaces = {
      0 = {
        network        = "core_wan"
        subnetwork_tag = "network_appliance"
      }
      1 = {
        network        = "distro_lan"
        subnetwork_tag = "network_appliance"
      }
    }
  }

  _core_wan-to-distro_lan-vyos-map = merge([
    for k1, v1 in local.core_wan-to-distro_lan-vyos.zones : {
      for idx in range(v1) :
      format("%s-vyos-%s-%02d", local.core_wan-to-distro_lan-vyos.prefix, k1, idx) => {
        name = format("%s-vyos-%s-%02d-%s",
          local.core_wan-to-distro_lan-vyos.prefix,
          join("", [
            local.continent_short_name[split("-", k1)[0]],
            replace(join("", slice(split("-", k1), 1, 3)), "/(n)orth|(s)outh|(e)ast|(w)est|(c)entral/", "$1$2$3$4$5")
          ]),
          idx,
          random_id.id.hex
        )
        machine_type    = local.core_wan-to-distro_lan-vyos.machine_type
        zone            = k1
        region          = regex("^(.*)-.", k1)[0]
        service_account = local.core_wan-to-distro_lan-vyos.service_account
      }
    }
  ]...)

  core_wan-to-distro_lan-vyos-map = {
    for k1, v1 in local._core_wan-to-distro_lan-vyos-map : k1 => merge(v1, {

      bucket_object = format("core_wan-to-distro_lan-vyos-%s.conf", local._regions[v1.region])

      subnetworks = { for k2, v2 in local.core_wan-to-distro_lan-vyos.interfaces : format("%s-%s", k1, k2) => {
        nic = format("eth%d", k2)
        cidr_range = [
          for subnetwork in local._networks[v2.network].subnetworks :
          subnetwork.ip_cidr_range if(
            subnetwork.region == v1.region &&
            contains(subnetwork.tags, v2.subnetwork_tag)
          )
        ][0]

        network_prefix = local._networks[v2.network].prefix
        region         = v1.region
        ncc_spoke = format("%s-vyos-%s",
          local._networks[v2.network].prefix,
          local._regions[v1.region]
        )
        network = v2.network
        subnetwork = format(
          "%s-%s", local._networks[v2.network].prefix,
          replace(
            [
              for subnetwork in local._networks[v2.network].subnetworks :
              subnetwork.ip_cidr_range if(
                subnetwork.region == v1.region &&
                contains(subnetwork.tags, v2.subnetwork_tag)
              )
            ][0],
            "//|\\./", "-"
          )
        )
        }
      }
    })
  }

  core_wan-to-distro_lan-vyos-bootstrap = { for k1, v1 in local.core_wan-to-distro_lan-vyos-map : k1 => {
    name = v1.name
    local_asn = try(
      local.core_wan-to-distro_lan-vyos.regional_asn[v1.region],
      local.core_wan-to-distro_lan-vyos.shared_asn,
      local._default_asn,
    )

    interfaces = { for k2, v2 in v1.subnetworks : k2 => {
      network_prefix = v2.network_prefix
      nic            = v2.nic
      peer_addresses = [
        cidrhost(v2.cidr_range, -3),
        cidrhost(v2.cidr_range, -4)
      ]
      peer_asn = try(
        local._networks[v2.network].regional_asn[v1.region],
        local._networks[v2.network].shared_asn,
        local._default_asn
      )
      }
    }
    }
  }
}

resource "null_resource" "core_wan-to-distro_lan-vyos" {
  depends_on = [
    google_network_connectivity_hub.core_wan,
    google_network_connectivity_hub.distro_lan,
    google_compute_router.core_wan,
    google_compute_router.distro_lan,
    google_compute_subnetwork.core_wan,
    google_compute_subnetwork.distro_lan,
    google_compute_router_interface.core_wan-appliance-nic0,
    google_compute_router_interface.core_wan-appliance-nic1,
    google_compute_router_interface.distro_lan-appliance-nic0,
    google_compute_router_interface.distro_lan-appliance-nic1,
  ]
}

resource "google_compute_address" "core_wan-to-distro_lan-vyos" {
  for_each     = merge(values(local.core_wan-to-distro_lan-vyos-map).*.subnetworks...)
  name         = each.key
  project      = var.project_id
  region       = each.value.region
  address_type = "INTERNAL"
  purpose      = "GCE_ENDPOINT"
  subnetwork   = format("%s-%s", each.value.subnetwork, random_id.id.hex)

  depends_on = [
    null_resource.core_wan-to-distro_lan-vyos,
  ]
}

resource "local_file" "core_wan-to-distro_lan-vyos" {
  for_each = local.core_wan-to-distro_lan-vyos-bootstrap
  filename = "./config/${each.value.name}/config.boot"
  content = templatefile("${path.module}/template/${local.core_wan-to-distro_lan-vyos.prefix}/config.boot.tmpl",
    {
      "interfaces" : each.value.interfaces,
      "asn" : each.value.local_asn,
      "neighbors" : flatten([
        for v1 in each.value.interfaces : [
          for k2 in v1.peer_addresses : {
            asn     = v1.peer_asn,
            address = k2,
            network_tag = upper(v1.network_prefix)
          }
        ]
      ])
    }
  )
}

resource "google_storage_bucket_object" "core_wan-to-distro_lan-vyos" {
  for_each = local.core_wan-to-distro_lan-vyos-bootstrap
  name     = format("%s.conf", each.value.name)
  bucket   = google_storage_bucket.bucket.name
  content = templatefile("${path.module}/template/${local.core_wan-to-distro_lan-vyos.prefix}/config.boot.tmpl",
    {
      "interfaces" : each.value.interfaces,
      "asn" : each.value.local_asn,
      "neighbors" : flatten([
        for v1 in each.value.interfaces : [
          for k2 in v1.peer_addresses : {
            asn     = v1.peer_asn,
            address = k2,
            network_tag = upper(v1.network_prefix)
          }
        ]
      ])
    }
  )

  lifecycle {
    ignore_changes = [detect_md5hash]
  }
}

resource "google_pubsub_subscription" "core_wan-to-distro_lan-vyos" {
  for_each = local.core_wan-to-distro_lan-vyos-map

  project = var.project_id
  name    = each.value.name
  topic   = google_pubsub_topic.configuration_update_topic.name

  filter = "attributes.objectId = \"${each.value.bucket_object}\""

  ack_deadline_seconds = 30
}



# resource "google_pubsub_subscription_iam_policy" "distro_lan_to_access_truested_vyos_usc1" {
#   count = length(google_pubsub_subscription.distro_lan_to_access_truested_vyos_usc1)

#   project      = var.project_id
#   subscription = google_pubsub_subscription.distro_lan_to_access_truested_vyos_usc1[count.index].name
#   policy_data  = data.google_iam_policy.subscription_subscriber.policy_data
# }

# resource "google_storage_notification" "core_wan_to_distro_lan_vyos_usc1" {
#   bucket             = google_storage_bucket.bucket.name
#   payload_format     = "JSON_API_V1"
#   topic              = google_pubsub_topic.configuration_update_topic.id
#   event_types        = ["OBJECT_FINALIZE", "OBJECT_METADATA_UPDATE"]
#   object_name_prefix = "core_wan_to_distro_lan_vyos_usc1"
#   depends_on         = [google_pubsub_topic_iam_member.pubsub_notification_event]
# }


resource "google_compute_instance" "core_wan-to-distro_lan-vyos" {
  for_each = local.core_wan-to-distro_lan-vyos-map

  depends_on = [
    null_resource.core_wan-to-distro_lan-vyos,
    google_storage_bucket_object.core_wan-to-distro_lan-vyos,
    google_pubsub_subscription.core_wan-to-distro_lan-vyos,
    google_compute_address.core_wan-to-distro_lan-vyos,
  ]

  project = var.project_id

  name = each.value.name

  zone = each.value.zone

  boot_disk {
    auto_delete = true
    device_name = each.value.name

    initialize_params {
      image = "projects/rteller-demo-host-aaaa/global/images/vyos-advanced-v1-3-5"
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
    serial-port-enable      = "TRUE"
    pubsub-subscription     = each.value.name
    configuration_bucket_id = google_storage_bucket.bucket.name
    configuration_object_id = each.value.bucket_object
  }

  dynamic "network_interface" {
    for_each = each.value.subnetworks
    content {
      network_ip         = google_compute_address.core_wan-to-distro_lan-vyos[network_interface.key].address
      subnetwork         = format("%s-%s", network_interface.value.subnetwork, random_id.id.hex)
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

resource "google_network_connectivity_spoke" "core_wan-to-distro_lan-vyos" {
  for_each = { for x in distinct(values(merge(values(local.core_wan-to-distro_lan-vyos-map).*.subnetworks...))) : x.ncc_spoke => x }

  project = var.project_id

  name     = format("appliance-%s-%s-%s", random_id.core_wan-to-distro_lan-seed.hex, each.key, random_id.id.hex)
  hub      = format("%s-%s", each.value.network_prefix, random_id.id.hex)
  location = each.value.region

  linked_router_appliance_instances {
    site_to_site_data_transfer = true
    dynamic "instances" {
      for_each = { for k1, v1 in google_compute_instance.core_wan-to-distro_lan-vyos : k1 => v1 if startswith(v1.zone, each.value.region) }
      content {
        virtual_machine = instances.value.self_link
        ip_address = [
          for k2, v2 in instances.value.network_interface : v2.network_ip if endswith(v2.subnetwork, format("%s-%s", each.value.subnetwork, random_id.id.hex))
        ][0]
      }
    }
  }

  depends_on = [
    null_resource.core_wan-to-distro_lan-vyos,
    google_compute_address.core_wan-to-distro_lan-vyos,
    google_compute_instance.core_wan-to-distro_lan-vyos,
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_peer
resource "google_compute_router_peer" "core_wan-to-distro_lan-vyos-peer0" {
  for_each = merge(values(local.core_wan-to-distro_lan-vyos-map).*.subnetworks...)

  project = var.project_id

  name      = format("%s-peer0", each.key)
  router    = format("%s-%s", each.value.network_prefix, random_id.id.hex)
  region    = each.value.region
  interface = format("%s-%s-%s", local._networks[each.value.network].prefix, format("nic%02d", 0), random_id.id.hex)

  peer_asn = try(
    local.core_wan-to-distro_lan-vyos.regional_asn[each.value.region],
    local.core_wan-to-distro_lan-vyos.shared_asn,
    local._default_asn,
  )

  router_appliance_instance = google_compute_instance.core_wan-to-distro_lan-vyos[regex("^(.*)-.", each.key)[0]].self_link
  peer_ip_address           = google_compute_address.core_wan-to-distro_lan-vyos[each.key].address
  advertised_route_priority = 100

  depends_on = [
    null_resource.core_wan-to-distro_lan-vyos,
    google_compute_instance.core_wan-to-distro_lan-vyos,
    google_network_connectivity_spoke.core_wan-to-distro_lan-vyos,
  ]
}

resource "google_compute_router_peer" "core_wan-to-distro_lan-vyos-peer1" {
  for_each = merge(values(local.core_wan-to-distro_lan-vyos-map).*.subnetworks...)

  project = var.project_id

  name      = format("%s-peer1", each.key)
  router    = format("%s-%s", each.value.network_prefix, random_id.id.hex)
  region    = each.value.region
  interface = format("%s-%s-%s", local._networks[each.value.network].prefix, format("nic%02d", 1), random_id.id.hex)

  peer_asn = try(
    local.core_wan-to-distro_lan-vyos.regional_asn[each.value.region],
    local.core_wan-to-distro_lan-vyos.shared_asn,
    local._default_asn,
  )
  router_appliance_instance = google_compute_instance.core_wan-to-distro_lan-vyos[regex("^(.*)-.", each.key)[0]].self_link
  peer_ip_address           = google_compute_address.core_wan-to-distro_lan-vyos[each.key].address
  advertised_route_priority = 100

  depends_on = [
    null_resource.core_wan-to-distro_lan-vyos,
    google_compute_router_peer.core_wan-to-distro_lan-vyos-peer0,
    google_compute_instance.core_wan-to-distro_lan-vyos,
    google_network_connectivity_spoke.core_wan-to-distro_lan-vyos,
  ]
}

resource "random_id" "distro_lan-to-access_trusted-seed" {
  byte_length = 2

}

locals {
  distro_lan-to-access_trusted-vyos = {
    asn          = 65533
    prefix       = "distro-lan-to-access-trusted"
    machine_type = "n2d-standard-4"
    zones = {
      "us-east4-a" = 1
      "us-west1-a" = 0
    }
    service_account = google_service_account.vyos_compute_sa.email
    interfaces = {
      0 = {
        network        = "distro_lan"
        subnetwork_tag = "network_appliance"
      }
      1 = {
        network        = "access_trusted_transit"
        subnetwork_tag = "network_appliance"
      }
      2 = {
        network        = "access_trusted_aa00"
        subnetwork_tag = "network_appliance"
      }
      3 = {
        network        = "access_trusted_ab00"
        subnetwork_tag = "network_appliance"
      }
    }
  }

  _distro_lan-to-access_trusted-vyos-map = merge([
    for k1, v1 in local.distro_lan-to-access_trusted-vyos.zones : {
      for idx in range(v1) :
      format("%s-vyos-%s-%02d", local.distro_lan-to-access_trusted-vyos.prefix, k1, idx) => {
        name = format("%s-vyos-%s-%02d-%s",
          local.distro_lan-to-access_trusted-vyos.prefix,
          join("", [
            local.continent_short_name[split("-", k1)[0]],
            replace(join("", slice(split("-", k1), 1, 3)), "/(n)orth|(s)outh|(e)ast|(w)est|(c)entral/", "$1$2$3$4$5")
          ]),
          idx,
          random_id.id.hex
        )
        machine_type    = local.distro_lan-to-access_trusted-vyos.machine_type
        zone            = k1
        region          = regex("^(.*)-.", k1)[0]
        service_account = local.distro_lan-to-access_trusted-vyos.service_account
      }
    }
  ]...)

  distro_lan-to-access_trusted-vyos-map = {
    for k1, v1 in local._distro_lan-to-access_trusted-vyos-map : k1 => merge(v1, {

      bucket_object = format("distro_lan-to-access_trusted-vyos-%s.conf", local._regions[v1.region])

      subnetworks = { for k2, v2 in local.distro_lan-to-access_trusted-vyos.interfaces : format("%s-%s", k1, k2) => {
        # instance = v1.name
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
}

resource "null_resource" "distro_lan-to-access_trusted-vyos" {
  depends_on = [
    google_network_connectivity_hub.distro_lan,
    google_network_connectivity_hub.access_trusted_transit,
    google_network_connectivity_hub.access_trusted_aa00,
    google_network_connectivity_hub.access_trusted_ab00,
    google_compute_router.distro_lan,
    google_compute_router.access_trusted_transit,
    google_compute_router.access_trusted_aa00,
    google_compute_router.access_trusted_ab00,
    google_compute_subnetwork.distro_lan,
    google_compute_subnetwork.access_trusted_transit,
    google_compute_subnetwork.access_trusted_ab00,
    google_compute_subnetwork.access_trusted_ab00,
    google_compute_router_interface.distro_lan-appliance-nic0,
    google_compute_router_interface.distro_lan-appliance-nic1,
    google_compute_router_interface.access_trusted_transit-appliance-nic0,
    google_compute_router_interface.access_trusted_transit-appliance-nic1,
    google_compute_router_interface.access_trusted_aa00-appliance-nic0,
    google_compute_router_interface.access_trusted_aa00-appliance-nic1,
    google_compute_router_interface.access_trusted_ab00-appliance-nic0,
    google_compute_router_interface.access_trusted_ab00-appliance-nic1,
  ]
}

resource "google_compute_address" "distro_lan-to-access_trusted-vyos" {
  for_each     = merge(values(local.distro_lan-to-access_trusted-vyos-map).*.subnetworks...)
  name         = each.key
  project      = var.project_id
  region       = each.value.region
  address_type = "INTERNAL"
  purpose      = "GCE_ENDPOINT"
  subnetwork   = format("%s-%s", each.value.subnetwork, random_id.id.hex)

  depends_on = [
    null_resource.distro_lan-to-access_trusted-vyos,
  ]
}

resource "google_storage_bucket_object" "distro_lan-to-access_trusted-vyos" {
  for_each = toset(distinct(values(local.distro_lan-to-access_trusted-vyos-map).*.bucket_object))
  name     = each.key
  bucket   = google_storage_bucket.bucket.name
  content  = "."

  lifecycle {
    ignore_changes = [detect_md5hash]
  }
}

resource "google_pubsub_subscription" "distro_lan-to-access_trusted-vyos" {
  for_each = local.distro_lan-to-access_trusted-vyos-map

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


resource "google_compute_instance" "distro_lan-to-access_trusted-vyos" {
  for_each = local.distro_lan-to-access_trusted-vyos-map

  depends_on = [
    null_resource.distro_lan-to-access_trusted-vyos,
    google_storage_bucket_object.distro_lan-to-access_trusted-vyos,
    google_pubsub_subscription.distro_lan-to-access_trusted-vyos,
    google_compute_address.distro_lan-to-access_trusted-vyos,
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

  allow_stopping_for_update = true
  can_ip_forward            = true
  deletion_protection       = false
  enable_display            = false

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
      network_ip         = google_compute_address.distro_lan-to-access_trusted-vyos[network_interface.key].address
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

resource "google_network_connectivity_spoke" "distro_lan-to-access_trusted-vyos" {
  for_each = { for x in distinct(values(merge(values(local.distro_lan-to-access_trusted-vyos-map).*.subnetworks...))) : x.ncc_spoke => x }

  project = var.project_id

  name     = format("appliance-%s-%s-%s", random_id.distro_lan-to-access_trusted-seed.hex, each.key, random_id.id.hex)
  hub      = format("%s-%s", each.value.network_prefix, random_id.id.hex)
  location = each.value.region

  linked_router_appliance_instances {
    site_to_site_data_transfer = true
    dynamic "instances" {
      for_each = { for k1, v1 in google_compute_instance.distro_lan-to-access_trusted-vyos : k1 => v1 if startswith(v1.zone, each.value.region) }
      content {
        virtual_machine = instances.value.self_link
        ip_address = [
          for k2, v2 in instances.value.network_interface : v2.network_ip if endswith(v2.subnetwork, format("%s-%s", each.value.subnetwork, random_id.id.hex))
        ][0]
      }
    }
  }

  depends_on = [
    null_resource.distro_lan-to-access_trusted-vyos,
    google_compute_address.distro_lan-to-access_trusted-vyos,
    google_compute_instance.distro_lan-to-access_trusted-vyos,
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_peer
resource "google_compute_router_peer" "distro_lan-to-access_trusted-vyos-peer0" {
  for_each = merge(values(local.distro_lan-to-access_trusted-vyos-map).*.subnetworks...)

  project = var.project_id

  name      = format("%s-peer0", each.key)
  router    = format("%s-%s", each.value.network_prefix, random_id.id.hex)
  region    = each.value.region
  interface = format("%s-%s-%s", local._networks[each.value.network].prefix, format("nic%02d", 0), random_id.id.hex)

  peer_asn                  = local.distro_lan-to-access_trusted-vyos.asn
  router_appliance_instance = google_compute_instance.distro_lan-to-access_trusted-vyos[regex("^(.*)-.", each.key)[0]].self_link
  peer_ip_address           = google_compute_address.distro_lan-to-access_trusted-vyos[each.key].address
  advertised_route_priority = 100

  depends_on = [
    null_resource.distro_lan-to-access_trusted-vyos,
    google_compute_instance.distro_lan-to-access_trusted-vyos,
    google_network_connectivity_spoke.distro_lan-to-access_trusted-vyos,
  ]
}

resource "google_compute_router_peer" "distro_lan-to-access_trusted-vyos-peer1" {
  for_each = merge(values(local.distro_lan-to-access_trusted-vyos-map).*.subnetworks...)

  project = var.project_id

  name      = format("%s-peer1", each.key)
  router    = format("%s-%s", each.value.network_prefix, random_id.id.hex)
  region    = each.value.region
  interface = format("%s-%s-%s", local._networks[each.value.network].prefix, format("nic%02d", 1), random_id.id.hex)

  peer_asn                  = local.distro_lan-to-access_trusted-vyos.asn
  router_appliance_instance = google_compute_instance.distro_lan-to-access_trusted-vyos[regex("^(.*)-.", each.key)[0]].self_link
  peer_ip_address           = google_compute_address.distro_lan-to-access_trusted-vyos[each.key].address
  advertised_route_priority = 100

  depends_on = [
    null_resource.distro_lan-to-access_trusted-vyos,
    google_compute_router_peer.distro_lan-to-access_trusted-vyos-peer0,
    google_compute_instance.distro_lan-to-access_trusted-vyos,
    google_network_connectivity_spoke.distro_lan-to-access_trusted-vyos,
  ]
}



# resource "google_compute_instance" "distro_lan_to_access_truested_vyos_usc1" {
#   count   = 2
#   project = var.project_id

#   name = format("distro-lan-to-access-trusted-vyos-%s-%02d-%s", "usc1", count.index, random_id.id.hex)

#   zone = "us-central1-b"

#   boot_disk {
#     auto_delete = true
#     device_name = "instance-1"

#     initialize_params {
#       image = "projects/rteller-demo-host-aaaa/global/images/vyos-advanced-v1-3-5"
#       size  = 10
#       type  = "pd-standard"
#     }

#     mode = "READ_WRITE"
#   }

#   can_ip_forward      = true
#   deletion_protection = false
#   enable_display      = false

#   machine_type = "n2d-standard-4"

#   metadata = {
#     serial-port-enable      = "TRUE"
#     pubsub-subscription     = format("distro-lan-to-access-trusted-vyos-%s-%02d-%s", "usc1", count.index, random_id.id.hex)
#     configuration_bucket_id = google_storage_bucket_object.distro_lan_to_access_truested_vyos_usc1.bucket
#     configuration_object_id = google_storage_bucket_object.distro_lan_to_access_truested_vyos_usc1.name
#   }


#   network_interface {
#     subnetwork = google_compute_subnetwork.distro_lan[
#       [for x in local._networks.distro_lan.subnetworks : x.ip_cidr_range if contains(try(x.tags, []), "network_appliance") && x.region == "us-central1"][0]
#     ].self_link
#   }

#   network_interface {
#     subnetwork = google_compute_subnetwork.access_trusted_aa00[
#       [for x in local._networks.access_trusted_aa00.subnetworks : x.ip_cidr_range if contains(try(x.tags, []), "network_appliance") && x.region == "us-central1"][0]
#     ].self_link
#   }

#   scheduling {
#     automatic_restart   = true
#     on_host_maintenance = "MIGRATE"
#     preemptible         = false
#     provisioning_model  = "STANDARD"
#   }

#   service_account {
#     email  = google_service_account.vyos_compute_sa.email
#     scopes = ["https://www.googleapis.com/auth/cloud-platform"]
#   }

#   lifecycle {
#     ignore_changes = [metadata["ssh-keys"]]
#   }
# }

# # https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/network_connectivity_spoke
# resource "google_network_connectivity_spoke" "core_wan_appliance_usc1" {
#   project = var.project_id

#   name = format("%s-%s-%s-%s",
#     local._network_core_wan.prefix,
#     "appliance",
#     local._regions["us-central1"],
#   random_id.id.hex, )

#   location = "us-central1"

#   hub = google_network_connectivity_hub.core_wan.id

#   linked_router_appliance_instances {
#     site_to_site_data_transfer = true
#     dynamic "instances" {
#       for_each = google_compute_instance.core_wan_to_distro_lan_vyos_usc1
#       content {
#         virtual_machine = instances.value.self_link
#         ip_address      = instances.value.network_interface[0].network_ip
#       }
#     }
#   }
# }

# resource "google_network_connectivity_spoke" "distro_lan_appliance_northbound_usc1" {
#   project = var.project_id

#   name = format("%s-%s-%s-%s",
#     local._network_distro_lan.prefix,
#     "appliance-northbound",
#     local._regions["us-central1"],
#   random_id.id.hex, )

#   location = "us-central1"

#   hub = google_network_connectivity_hub.distro_lan.id

#   linked_router_appliance_instances {
#     site_to_site_data_transfer = true
#     dynamic "instances" {
#       for_each = google_compute_instance.core_wan_to_distro_lan_vyos_usc1
#       content {
#         virtual_machine = instances.value.self_link
#         ip_address      = instances.value.network_interface[1].network_ip
#       }
#     }
#   }
# }

# resource "google_network_connectivity_spoke" "distro_lan_appliance_southbound_usc1" {
#   project = var.project_id

#   name = format("%s-%s-%s-%s",
#     local._network_distro_lan.prefix,
#     "appliance-southbound",
#     local._regions["us-central1"],
#   random_id.id.hex, )

#   location = "us-central1"

#   hub = google_network_connectivity_hub.distro_lan.id

#   linked_router_appliance_instances {
#     site_to_site_data_transfer = true
#     dynamic "instances" {
#       for_each = google_compute_instance.distro_lan_to_access_truested_vyos_usc1
#       content {
#         virtual_machine = instances.value.self_link
#         ip_address      = instances.value.network_interface[0].network_ip
#       }
#     }
#   }
# }

# resource "google_network_connectivity_spoke" "access_trusted_aa00_appliance_usc1" {
#   project = var.project_id

#   name = format("%s-%s-%s-%s",
#     local._network_access_trusted_aa00.prefix,
#     "appliance",
#     local._regions["us-central1"],
#   random_id.id.hex, )
#   location = "us-central1"

#   hub = google_network_connectivity_hub.access_trusted_aa00.id

#   linked_router_appliance_instances {
#     site_to_site_data_transfer = true
#     dynamic "instances" {
#       for_each = google_compute_instance.distro_lan_to_access_truested_vyos_usc1
#       content {
#         virtual_machine = instances.value.self_link
#         ip_address      = instances.value.network_interface[1].network_ip
#       }
#     }
#   }
# }

# # resource "google_network_connectivity_spoke" "access_trusted_0001_appliance_usc1" {
# #   project = var.project_id

# #   name = format("%s-%s-%s-%s",
# #     local._network_access_trusted_0001.prefix,
# #     "appliance",
# #     local._regions["us-central1"],
# #   random_id.id.hex, )
# #   location = "us-central1"

# #   hub = google_network_connectivity_hub.access_trusted_0001.id

# #   linked_router_appliance_instances {
# #     site_to_site_data_transfer = true
# #     dynamic "instances" {
# #       for_each = google_compute_instance.distro_lan_to_access_truested_vyos_usc1
# #       content {
# #         virtual_machine = instances.value.self_link
# #         ip_address      = instances.value.network_interface[2].network_ip
# #       }
# #     }
# #   }
# # }

# # resource "google_network_connectivity_spoke" "access_trusted_0002_appliance_usc1" {
# #   project = var.project_id

# #   name = format("%s-%s-%s-%s",
# #     local._network_access_trusted_0002.prefix,
# #     "appliance",
# #     local._regions["us-central1"],
# #   random_id.id.hex, )
# #   location = "us-central1"

# #   hub = google_network_connectivity_hub.access_trusted_0002.id

# #   linked_router_appliance_instances {
# #     site_to_site_data_transfer = true
# #     dynamic "instances" {
# #       for_each = google_compute_instance.distro_lan_to_access_truested_vyos_usc1
# #       content {
# #         virtual_machine = instances.value.self_link
# #         ip_address      = instances.value.network_interface[3].network_ip
# #       }
# #     }
# #   }
# # }

# # https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_peer
# resource "google_compute_router_peer" "core_wan_usc1_nic0" {
#   for_each = { for idx, instance in google_compute_instance.core_wan_to_distro_lan_vyos_usc1 : idx => instance }

#   project = var.project_id

#   name      = format("%s-%s", each.value.name, "nic0")
#   router    = google_compute_router.core_wan["us-central1"].name
#   region    = google_compute_router.core_wan["us-central1"].region
#   interface = google_compute_router_interface.core_wan-appliance-nic0["us-central1"].name

#   peer_asn                  = 65534
#   router_appliance_instance = each.value.self_link
#   peer_ip_address           = each.value.network_interface[0].network_ip
#   advertised_route_priority = 100 + each.key

#   depends_on = [
#     google_network_connectivity_spoke.core_wan_appliance_usc1
#   ]
# }

# resource "google_compute_router_peer" "core_wan_usc1_nic1" {
#   for_each = { for idx, instance in google_compute_instance.core_wan_to_distro_lan_vyos_usc1 : idx => instance }

#   project = var.project_id

#   name      = format("%s-%s", each.value.name, "nic1")
#   router    = google_compute_router.core_wan["us-central1"].name
#   region    = google_compute_router.core_wan["us-central1"].region
#   interface = google_compute_router_interface.core_wan-appliance-nic1["us-central1"].name



#   peer_asn                  = 65534
#   router_appliance_instance = each.value.self_link
#   peer_ip_address           = each.value.network_interface[0].network_ip
#   advertised_route_priority = 200 + each.key

#   depends_on = [
#     google_network_connectivity_spoke.core_wan_appliance_usc1
#   ]
# }

# resource "google_compute_router_peer" "distro_lan_appliance_northbound_usc1_nic0" {
#   for_each = { for idx, instance in google_compute_instance.core_wan_to_distro_lan_vyos_usc1 : idx => instance }

#   project = var.project_id

#   name      = format("%s-%s", each.value.name, "nic0")
#   router    = google_compute_router.distro_lan["us-central1"].name
#   region    = google_compute_router.distro_lan["us-central1"].region
#   interface = google_compute_router_interface.distro_lan-appliance-nic0["us-central1"].name

#   peer_asn                  = 65534
#   router_appliance_instance = each.value.self_link
#   peer_ip_address           = each.value.network_interface[1].network_ip
#   advertised_route_priority = 100 + each.key

#   depends_on = [
#     google_network_connectivity_spoke.distro_lan_appliance_northbound_usc1
#   ]
# }

# resource "google_compute_router_peer" "distro_lan_appliance_northbound_usc1_nic1" {
#   for_each = { for idx, instance in google_compute_instance.core_wan_to_distro_lan_vyos_usc1 : idx => instance }

#   project = var.project_id

#   name      = format("%s-%s", each.value.name, "nic1")
#   router    = google_compute_router.distro_lan["us-central1"].name
#   region    = google_compute_router.distro_lan["us-central1"].region
#   interface = google_compute_router_interface.distro_lan-appliance-nic1["us-central1"].name

#   peer_asn                  = 65534
#   router_appliance_instance = each.value.self_link
#   peer_ip_address           = each.value.network_interface[1].network_ip
#   advertised_route_priority = 200 + each.key

#   depends_on = [
#     google_network_connectivity_spoke.distro_lan_appliance_northbound_usc1
#   ]
# }

# resource "google_compute_router_peer" "distro_lan_appliance_southbound_usc1_nic0" {
#   for_each = { for idx, instance in google_compute_instance.distro_lan_to_access_truested_vyos_usc1 : idx => instance }

#   project = var.project_id

#   name      = format("%s-%s", each.value.name, "nic0")
#   router    = google_compute_router.distro_lan["us-central1"].name
#   region    = google_compute_router.distro_lan["us-central1"].region
#   interface = google_compute_router_interface.distro_lan-appliance-nic0["us-central1"].name

#   peer_asn                  = 65533
#   router_appliance_instance = each.value.self_link
#   peer_ip_address           = each.value.network_interface[0].network_ip
#   advertised_route_priority = 100 + each.key

#   depends_on = [
#     google_network_connectivity_spoke.distro_lan_appliance_southbound_usc1
#   ]
# }

# resource "google_compute_router_peer" "distro_lan_appliance_southbound_usc1_nic1" {
#   for_each = { for idx, instance in google_compute_instance.distro_lan_to_access_truested_vyos_usc1 : idx => instance }

#   project = var.project_id

#   name      = format("%s-%s", each.value.name, "nic1")
#   router    = google_compute_router.distro_lan["us-central1"].name
#   region    = google_compute_router.distro_lan["us-central1"].region
#   interface = google_compute_router_interface.distro_lan-appliance-nic1["us-central1"].name

#   peer_asn                  = 65533
#   router_appliance_instance = each.value.self_link
#   peer_ip_address           = each.value.network_interface[0].network_ip
#   advertised_route_priority = 200 + each.key


#   depends_on = [
#     google_network_connectivity_spoke.distro_lan_appliance_southbound_usc1
#   ]
# }

# resource "google_compute_router_peer" "access_trusted_aa00_appliance_usc1_nic0" {
#   for_each = { for idx, instance in google_compute_instance.distro_lan_to_access_truested_vyos_usc1 : idx => instance }

#   project = var.project_id

#   name      = format("%s-%s", each.value.name, "nic0")
#   router    = google_compute_router.access_trusted_aa00["us-central1"].name
#   region    = google_compute_router.access_trusted_aa00["us-central1"].region
#   interface = google_compute_router_interface.access_trusted_aa00-appliance-nic0["us-central1"].name

#   peer_asn                  = 65533
#   router_appliance_instance = each.value.self_link
#   peer_ip_address           = each.value.network_interface[1].network_ip
#   advertised_route_priority = 100 + each.key

#   depends_on = [
#     google_network_connectivity_spoke.access_trusted_aa00_appliance_usc1
#   ]
# }

# resource "google_compute_router_peer" "access_trusted_aa00_appliance_usc1_nic1" {
#   for_each = { for idx, instance in google_compute_instance.distro_lan_to_access_truested_vyos_usc1 : idx => instance }

#   project = var.project_id

#   name      = format("%s-%s", each.value.name, "nic1")
#   router    = google_compute_router.access_trusted_aa00["us-central1"].name
#   region    = google_compute_router.access_trusted_aa00["us-central1"].region
#   interface = google_compute_router_interface.access_trusted_aa00-appliance-nic1["us-central1"].name

#   peer_asn                  = 65533
#   router_appliance_instance = each.value.self_link
#   peer_ip_address           = each.value.network_interface[1].network_ip
#   advertised_route_priority = 200 + each.key


#   depends_on = [
#     google_network_connectivity_spoke.access_trusted_aa00_appliance_usc1
#   ]
# }

# # resource "google_compute_router_peer" "access_trusted_0001_appliance_usc1_nic0" {
# #   for_each = { for idx, instance in google_compute_instance.distro_lan_to_access_truested_vyos_usc1 : idx => instance }

# #   project = var.project_id

# #   name      = format("%s-%s", each.value.name, "nic0")
# #   router    = google_compute_router.access_trusted_0001["us-central1"].name
# #   region    = google_compute_router.access_trusted_0001["us-central1"].region
# #   interface = google_compute_router_interface.access_trusted_0001-appliance-nic0["us-central1"].name

# #   peer_asn                  = 65533
# #   router_appliance_instance = each.value.self_link
# #   peer_ip_address           = each.value.network_interface[2].network_ip
# #   advertised_route_priority = 100 + each.key

# #   depends_on = [
# #     google_network_connectivity_spoke.access_trusted_0001_appliance_usc1
# #   ]
# # }

# # resource "google_compute_router_peer" "access_trusted_0001_appliance_usc1_nic1" {
# #   for_each = { for idx, instance in google_compute_instance.distro_lan_to_access_truested_vyos_usc1 : idx => instance }

# #   project = var.project_id

# #   name      = format("%s-%s", each.value.name, "nic1")
# #   router    = google_compute_router.access_trusted_0001["us-central1"].name
# #   region    = google_compute_router.access_trusted_0001["us-central1"].region
# #   interface = google_compute_router_interface.access_trusted_0001-appliance-nic1["us-central1"].name

# #   peer_asn                  = 65533
# #   router_appliance_instance = each.value.self_link
# #   peer_ip_address           = each.value.network_interface[2].network_ip
# #   advertised_route_priority = 200 + each.key


# #   depends_on = [
# #     google_network_connectivity_spoke.access_trusted_0001_appliance_usc1
# #   ]
# # }

# # resource "google_compute_router_peer" "access_trusted_0002_appliance_usc1_nic0" {
# #   for_each = { for idx, instance in google_compute_instance.distro_lan_to_access_truested_vyos_usc1 : idx => instance }

# #   project = var.project_id

# #   name      = format("%s-%s", each.value.name, "nic0")
# #   router    = google_compute_router.access_trusted_0002["us-central1"].name
# #   region    = google_compute_router.access_trusted_0002["us-central1"].region
# #   interface = google_compute_router_interface.access_trusted_0002-appliance-nic0["us-central1"].name

# #   peer_asn                  = 65533
# #   router_appliance_instance = each.value.self_link
# #   peer_ip_address           = each.value.network_interface[3].network_ip
# #   advertised_route_priority = 100 + each.key

# #   depends_on = [
# #     google_network_connectivity_spoke.access_trusted_0002_appliance_usc1
# #   ]
# # }

# # resource "google_compute_router_peer" "access_trusted_0002_appliance_usc1_nic1" {
# #   for_each = { for idx, instance in google_compute_instance.distro_lan_to_access_truested_vyos_usc1 : idx => instance }

# #   project = var.project_id

# #   name      = format("%s-%s", each.value.name, "nic1")
# #   router    = google_compute_router.access_trusted_0002["us-central1"].name
# #   region    = google_compute_router.access_trusted_0002["us-central1"].region
# #   interface = google_compute_router_interface.access_trusted_0002-appliance-nic1["us-central1"].name

# #   peer_asn                  = 65533
# #   router_appliance_instance = each.value.self_link
# #   peer_ip_address           = each.value.network_interface[3].network_ip
# #   advertised_route_priority = 200 + each.key


# #   depends_on = [
# #     google_network_connectivity_spoke.access_trusted_0002_appliance_usc1
# #   ]
# # }

# resource "google_pubsub_subscription" "core_wan_to_distro_lan_vyos_usc1" {
#   count = length(google_compute_instance.core_wan_to_distro_lan_vyos_usc1)

#   project = var.project_id
#   name    = google_compute_instance.core_wan_to_distro_lan_vyos_usc1[count.index].name
#   topic   = google_pubsub_topic.configuration_update_topic.name

#   filter = "attributes.objectId = \"core_wan_to_distro_lan_vyos_usc1.conf\""

#   ack_deadline_seconds = 30
# }

# resource "google_pubsub_subscription_iam_policy" "core_wan_to_distro_lan_vyos_usc1" {
#   count = length(google_pubsub_subscription.core_wan_to_distro_lan_vyos_usc1)

#   project      = var.project_id
#   subscription = google_pubsub_subscription.core_wan_to_distro_lan_vyos_usc1[count.index].name
#   policy_data  = data.google_iam_policy.subscription_subscriber.policy_data
# }

# resource "google_pubsub_subscription" "distro_lan_to_access_truested_vyos_usc1" {
#   count = length(google_compute_instance.distro_lan_to_access_truested_vyos_usc1)

#   project = var.project_id
#   name    = google_compute_instance.distro_lan_to_access_truested_vyos_usc1[count.index].name
#   topic   = google_pubsub_topic.configuration_update_topic.name

#   filter               = "attributes.objectId = \"distro_lan_to_access_truested_vyos_usc1.conf\""
#   ack_deadline_seconds = 30
# }

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

# resource "google_storage_notification" "distro_lan_to_access_truested_vyos_usc1" {
#   bucket             = google_storage_bucket.bucket.name
#   payload_format     = "JSON_API_V1"
#   topic              = google_pubsub_topic.configuration_update_topic.id
#   event_types        = ["OBJECT_FINALIZE", "OBJECT_METADATA_UPDATE"]
#   object_name_prefix = "distro_lan_to_access_truested_vyos_usc1"
#   depends_on         = [google_pubsub_topic_iam_member.pubsub_notification_event]
# }

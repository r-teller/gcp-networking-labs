resource "random_id" "core_wan-to-distro_lan-seed" {
  byte_length = 2
}


locals {
  core_wan-to-distro_lan-vyos = {
    asn          = 65534
    prefix       = "core-wan-to-distro-lan"
    machine_type = "n2d-standard-2"
    zones = {
      "us-west1-a" = 2
      "us-east4-a" = 1
    }
    service_account = google_service_account.vyos_compute_sa.email
    interfaces = {
      1 = {
        network        = "distro_lan"
        subnetwork_tag = "network_appliance"
      }
      0 = {
        network        = "core_wan"
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
      #   bucket = "core_wan_to_distro_lan_vyos_usc1.conf"
      bucket_object = format("core_wan-to-distro_lan-vyos-%s.conf", local._regions[v1.region])
      #   pubsub_subscription = format("core-wan-to-distro-lan-vyos-%s-%02d-%s", "usc1", count.index, random_id.id.hex)
      subnetworks = { for k2, v2 in local.core_wan-to-distro_lan-vyos.interfaces : format("%s-%s", k1, k2) => {
        # instance = v1.name
        cidr_range = [
          for subnetwork in local._networks[v2.network].subnetworks :
          subnetwork.ip_cidr_range if(
            subnetwork.region == v1.region &&
            contains(subnetwork.tags, v2.subnetwork_tag)
          )
        ][0]

        region  = v1.region
        router  = format("%s-%s", local._networks[v2.network].prefix, random_id.id.hex)
        ncc_hub = format("%s-%s", local._networks[v2.network].prefix, random_id.id.hex)
        ncc_spoke = format("%s-vyos-%s",
          local._networks[v2.network].prefix,
          local._regions[v1.region]
        )
        network = v2.network
        subnetwork = format(
          "%s-%s-%s", local._networks[v2.network].prefix,
          replace(
            [
              for subnetwork in local._networks[v2.network].subnetworks :
              subnetwork.ip_cidr_range if(
                subnetwork.region == v1.region &&
                contains(subnetwork.tags, v2.subnetwork_tag)
              )
            ][0],
            "//|\\./", "-"
          ),
          random_id.id.hex
        )
        }
      }
    })
  }
}

resource "google_compute_address" "core_wan-to-distro_lan-vyos" {
  for_each     = merge(values(local.core_wan-to-distro_lan-vyos-map).*.subnetworks...)
  name         = each.key
  project      = var.project_id
  region       = each.value.region
  address_type = "INTERNAL"
  purpose      = "GCE_ENDPOINT"
  subnetwork   = each.value.subnetwork

  depends_on = [
    google_compute_subnetwork.core_wan,
    google_compute_subnetwork.distro_lan,

  ]
}

resource "google_storage_bucket_object" "core_wan-to-distro_lan-vyos" {
  for_each = toset(distinct(values(local.core_wan-to-distro_lan-vyos-map).*.bucket_object))
  name     = each.key
  bucket   = google_storage_bucket.bucket.name
  content  = "."

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
    google_storage_bucket_object.core_wan-to-distro_lan-vyos,
    google_pubsub_subscription.core_wan-to-distro_lan-vyos,
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
      subnetwork         = network_interface.value.subnetwork
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

  name = format("appliance-%s-%s-%s", random_id.core_wan-to-distro_lan-seed.hex, each.key, random_id.id.hex)

  location = each.value.region

  hub = each.value.ncc_hub

  linked_router_appliance_instances {
    site_to_site_data_transfer = true
    dynamic "instances" {
      for_each = { for k1, v1 in google_compute_instance.core_wan-to-distro_lan-vyos : k1 => v1 if startswith(v1.zone, each.value.region) }
      content {
        virtual_machine = instances.value.self_link
        ip_address = [
          for k2, v2 in instances.value.network_interface : v2.network_ip if endswith(v2.subnetwork, each.value.subnetwork)
        ][0]
      }
    }
  }

  depends_on = [
    google_compute_instance.core_wan-to-distro_lan-vyos,
  ]
}

# output "foobar" {
#   value = [
#     for k, v in google_compute_instance.core_wan-to-distro_lan-vyos : {
#       for interface in v.network_interface
#       : format("%s-%s", k, interface.network_ip) => {
#         name       = v.name
#         region     = regex("^(.*)-.", v.zone)[0]
#         self_link  = v.self_link
#         network_ip = interface.network_ip
#       }
#     }
#   ]
# }

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_peer
resource "google_compute_router_peer" "core_wan-to-distro_lan-vyos-nic0" {
  for_each = merge(values(local.core_wan-to-distro_lan-vyos-map).*.subnetworks...)

  project = var.project_id

  name   = each.key
  router = each.value.router
  region = each.value.region
  # router    = google_compute_router.core_wan[each.value.region].name
  # interface = google_compute_router_interface.core_wan_appliance_nic0[each.value.region].name
  interface = format("%s-%s-%s", local._networks[each.value.network].prefix, format("nic%02d", 0), random_id.id.hex)

  peer_asn                  = local.core_wan-to-distro_lan-vyos.asn
  router_appliance_instance = google_compute_instance.core_wan-to-distro_lan-vyos[regex("^(.*)-.", each.key)[0]].self_link
  peer_ip_address           = google_compute_address.core_wan-to-distro_lan-vyos[each.key].address
  advertised_route_priority = 100

  depends_on = [
    google_compute_instance.core_wan-to-distro_lan-vyos,
    google_network_connectivity_spoke.core_wan-to-distro_lan-vyos,
  ]
}

resource "google_compute_router_peer" "core_wan-to-distro_lan-vyos-nic1" {
  for_each = merge(values(local.core_wan-to-distro_lan-vyos-map).*.subnetworks...)

  project = var.project_id

  name   = each.key
  router = each.value.router
  region = each.value.region

  interface = format("%s-%s-%s", local._networks[each.value.network].prefix, format("nic%02d", 1), random_id.id.hex)

  peer_asn                  = local.core_wan-to-distro_lan-vyos.asn
  router_appliance_instance = google_compute_instance.core_wan-to-distro_lan-vyos[regex("^(.*)-.", each.key)[0]].self_link
  peer_ip_address           = google_compute_address.core_wan-to-distro_lan-vyos[each.key].address
  advertised_route_priority = 100

  depends_on = [
    google_compute_instance.core_wan-to-distro_lan-vyos,
    google_network_connectivity_spoke.core_wan-to-distro_lan-vyos,
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
#   interface = google_compute_router_interface.core_wan_appliance_nic0["us-central1"].name

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
#   interface = google_compute_router_interface.core_wan_appliance_nic1["us-central1"].name



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
#   interface = google_compute_router_interface.distro_lan_appliance_nic0["us-central1"].name

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
#   interface = google_compute_router_interface.distro_lan_appliance_nic1["us-central1"].name

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
#   interface = google_compute_router_interface.distro_lan_appliance_nic0["us-central1"].name

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
#   interface = google_compute_router_interface.distro_lan_appliance_nic1["us-central1"].name

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
#   interface = google_compute_router_interface.access_trusted_aa00_appliance_nic0["us-central1"].name

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
#   interface = google_compute_router_interface.access_trusted_aa00_appliance_nic1["us-central1"].name

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
# #   interface = google_compute_router_interface.access_trusted_0001_appliance_nic0["us-central1"].name

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
# #   interface = google_compute_router_interface.access_trusted_0001_appliance_nic1["us-central1"].name

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
# #   interface = google_compute_router_interface.access_trusted_0002_appliance_nic0["us-central1"].name

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
# #   interface = google_compute_router_interface.access_trusted_0002_appliance_nic1["us-central1"].name

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
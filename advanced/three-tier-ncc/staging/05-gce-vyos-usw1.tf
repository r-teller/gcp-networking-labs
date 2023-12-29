resource "google_storage_bucket_object" "core_wan_to_distro_lan_vyos_usw1" {
  name    = "core_wan_to_distro_lan_vyos_usw1.conf"
  bucket  = google_storage_bucket.bucket.name
  content = "."

  lifecycle {
    ignore_changes = [detect_md5hash]
  }
}

resource "google_storage_bucket_object" "distro_lan_to_access_truested_vyos_usw1" {
  name    = "distro_lan_to_access_truested_vyos_usw1.conf"
  bucket  = google_storage_bucket.bucket.name
  content = "."

  lifecycle {
    ignore_changes = [detect_md5hash]
  }
}


resource "google_compute_instance" "core_wan_to_distro_lan_vyos_usw1" {
  count   = 2
  project = var.project_id

  name = format("core-wan-to-distro-lan-vyos-%s-%02d-%s", "usw1", count.index, random_id.id.hex)

  zone = "us-west1-b"

  boot_disk {
    auto_delete = true
    device_name = "instance-1"

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

  machine_type = "n2d-standard-2"

  metadata = {
    serial-port-enable      = "TRUE"
    pubsub-subscription     = format("core-wan-to-distro-lan-vyos-%s-%02d-%s", "usw1", count.index, random_id.id.hex)
    configuration_bucket_id = google_storage_bucket_object.core_wan_to_distro_lan_vyos_usw1.bucket
    configuration_object_id = google_storage_bucket_object.core_wan_to_distro_lan_vyos_usw1.name
  }


  network_interface {
    network_ip = cidrhost(google_compute_subnetwork.core_wan["us-west1"].ip_cidr_range, (count.index + 3))
    subnetwork = google_compute_subnetwork.core_wan["us-west1"].self_link
  }

  network_interface {
    network_ip = cidrhost(google_compute_subnetwork.distro_lan["us-west1"].ip_cidr_range, (count.index + 3))
    subnetwork = google_compute_subnetwork.distro_lan["us-west1"].self_link
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
    provisioning_model  = "STANDARD"
  }

  service_account {
    email  = google_service_account.vyos_compute_sa.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  lifecycle {
    ignore_changes = [metadata["ssh-keys"]]
  }
}

resource "google_compute_instance" "distro_lan_to_access_truested_vyos_usw1" {
  count   = 2
  project = var.project_id

  name = format("distro-lan-to-access-trusted-vyos-%s-%02d-%s", "usw1", count.index, random_id.id.hex)

  zone = "us-west1-b"

  boot_disk {
    auto_delete = true
    device_name = "instance-1"

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

  machine_type = "n2d-standard-4"

  metadata = {
    serial-port-enable      = "TRUE"
    pubsub-subscription     = format("distro-lan-to-access-trusted-vyos-%s-%02d-%s", "usw1", count.index, random_id.id.hex)
    configuration_bucket_id = google_storage_bucket_object.distro_lan_to_access_truested_vyos_usw1.bucket
    configuration_object_id = google_storage_bucket_object.distro_lan_to_access_truested_vyos_usw1.name
  }


  network_interface {
    network_ip = cidrhost(google_compute_subnetwork.distro_lan["us-west1"].ip_cidr_range, (count.index + 13))
    subnetwork = google_compute_subnetwork.distro_lan["us-west1"].self_link
  }

  network_interface {
    network_ip = cidrhost(google_compute_subnetwork.access_trusted_0000["us-west1"].ip_cidr_range, (count.index + 3))
    subnetwork = google_compute_subnetwork.access_trusted_0000["us-west1"].self_link
  }

  network_interface {
    network_ip = cidrhost(google_compute_subnetwork.access_trusted_0001["us-west1"].ip_cidr_range, (count.index + 3))
    subnetwork = google_compute_subnetwork.access_trusted_0001["us-west1"].self_link
  }

  network_interface {
    network_ip = cidrhost(google_compute_subnetwork.access_trusted_0002["us-west1"].ip_cidr_range, (count.index + 3))
    subnetwork = google_compute_subnetwork.access_trusted_0002["us-west1"].self_link
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
    provisioning_model  = "STANDARD"
  }

  service_account {
    email  = google_service_account.vyos_compute_sa.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  lifecycle {
    ignore_changes = [metadata["ssh-keys"]]
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/network_connectivity_spoke
resource "google_network_connectivity_spoke" "core_wan_appliance_usw1" {
  project = var.project_id

  name = format("%s-%s-%s-%s",
    local._network_core_wan.prefix,
    "appliance",
    local._regions["us-west1"],
  random_id.id.hex, )

  location = "us-west1"

  hub = google_network_connectivity_hub.core_wan.id

  linked_router_appliance_instances {
    site_to_site_data_transfer = true
    dynamic "instances" {
      for_each = google_compute_instance.core_wan_to_distro_lan_vyos_usw1
      content {
        virtual_machine = instances.value.self_link
        ip_address      = instances.value.network_interface[0].network_ip
      }
    }
  }
}

resource "google_network_connectivity_spoke" "distro_lan_appliance_northbound_usw1" {
  project = var.project_id

  name = format("%s-%s-%s-%s",
    local._network_distro_lan.prefix,
    "appliance-northbound",
    local._regions["us-west1"],
  random_id.id.hex, )

  location = "us-west1"

  hub = google_network_connectivity_hub.distro_lan.id

  linked_router_appliance_instances {
    site_to_site_data_transfer = true
    dynamic "instances" {
      for_each = google_compute_instance.core_wan_to_distro_lan_vyos_usw1
      content {
        virtual_machine = instances.value.self_link
        ip_address      = instances.value.network_interface[1].network_ip
      }
    }
  }
}

resource "google_network_connectivity_spoke" "distro_lan_appliance_southbound_usw1" {
  project = var.project_id

  name = format("%s-%s-%s-%s",
    local._network_distro_lan.prefix,
    "appliance-southbound",
    local._regions["us-west1"],
  random_id.id.hex, )

  location = "us-west1"

  hub = google_network_connectivity_hub.distro_lan.id

  linked_router_appliance_instances {
    site_to_site_data_transfer = true
    dynamic "instances" {
      for_each = google_compute_instance.distro_lan_to_access_truested_vyos_usw1
      content {
        virtual_machine = instances.value.self_link
        ip_address      = instances.value.network_interface[0].network_ip
      }
    }
  }
}

resource "google_network_connectivity_spoke" "access_trusted_0000_appliance_usw1" {
  project = var.project_id

  name = format("%s-%s-%s-%s",
    local._network_access_trusted_0000.prefix,
    "appliance",
    local._regions["us-west1"],
  random_id.id.hex, )
  location = "us-west1"

  hub = google_network_connectivity_hub.access_trusted_0000.id

  linked_router_appliance_instances {
    site_to_site_data_transfer = true
    dynamic "instances" {
      for_each = google_compute_instance.distro_lan_to_access_truested_vyos_usw1
      content {
        virtual_machine = instances.value.self_link
        ip_address      = instances.value.network_interface[1].network_ip
      }
    }
  }
}

resource "google_network_connectivity_spoke" "access_trusted_0001_appliance_usw1" {
  project = var.project_id

  name = format("%s-%s-%s-%s",
    local._network_access_trusted_0001.prefix,
    "appliance",
    local._regions["us-west1"],
  random_id.id.hex, )
  location = "us-west1"

  hub = google_network_connectivity_hub.access_trusted_0001.id

  linked_router_appliance_instances {
    site_to_site_data_transfer = true
    dynamic "instances" {
      for_each = google_compute_instance.distro_lan_to_access_truested_vyos_usw1
      content {
        virtual_machine = instances.value.self_link
        ip_address      = instances.value.network_interface[2].network_ip
      }
    }
  }
}

resource "google_network_connectivity_spoke" "access_trusted_0002_appliance_usw1" {
  project = var.project_id

  name = format("%s-%s-%s-%s",
    local._network_access_trusted_0002.prefix,
    "appliance",
    local._regions["us-west1"],
  random_id.id.hex, )
  location = "us-west1"

  hub = google_network_connectivity_hub.access_trusted_0002.id

  linked_router_appliance_instances {
    site_to_site_data_transfer = true
    dynamic "instances" {
      for_each = google_compute_instance.distro_lan_to_access_truested_vyos_usw1
      content {
        virtual_machine = instances.value.self_link
        ip_address      = instances.value.network_interface[3].network_ip
      }
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_peer
resource "google_compute_router_peer" "core_wan_usw1_nic0" {
  for_each = { for idx, instance in google_compute_instance.core_wan_to_distro_lan_vyos_usw1 : idx => instance }

  project = var.project_id

  name      = format("%s-%s", each.value.name, "nic0")
  router    = google_compute_router.core_wan["us-west1"].name
  region    = google_compute_router.core_wan["us-west1"].region
  interface = google_compute_router_interface.core_wan_appliance_nic0["us-west1"].name

  peer_asn                  = 65534
  router_appliance_instance = each.value.self_link
  peer_ip_address           = each.value.network_interface[0].network_ip
  advertised_route_priority = 100 + each.key

  depends_on = [
    google_network_connectivity_spoke.core_wan_appliance_usw1
  ]
}

resource "google_compute_router_peer" "core_wan_usw1_nic1" {
  for_each = { for idx, instance in google_compute_instance.core_wan_to_distro_lan_vyos_usw1 : idx => instance }

  project = var.project_id

  name      = format("%s-%s", each.value.name, "nic1")
  router    = google_compute_router.core_wan["us-west1"].name
  region    = google_compute_router.core_wan["us-west1"].region
  interface = google_compute_router_interface.core_wan_appliance_nic1["us-west1"].name



  peer_asn                  = 65534
  router_appliance_instance = each.value.self_link
  peer_ip_address           = each.value.network_interface[0].network_ip
  advertised_route_priority = 200 + each.key

  depends_on = [
    google_network_connectivity_spoke.core_wan_appliance_usw1
  ]
}

resource "google_compute_router_peer" "distro_lan_appliance_northbound_usw1_nic0" {
  for_each = { for idx, instance in google_compute_instance.core_wan_to_distro_lan_vyos_usw1 : idx => instance }

  project = var.project_id

  name      = format("%s-%s", each.value.name, "nic0")
  router    = google_compute_router.distro_lan["us-west1"].name
  region    = google_compute_router.distro_lan["us-west1"].region
  interface = google_compute_router_interface.distro_lan_appliance_nic0["us-west1"].name

  peer_asn                  = 65534
  router_appliance_instance = each.value.self_link
  peer_ip_address           = each.value.network_interface[1].network_ip
  advertised_route_priority = 100 + each.key

  depends_on = [
    google_network_connectivity_spoke.distro_lan_appliance_northbound_usw1
  ]
}

resource "google_compute_router_peer" "distro_lan_appliance_northbound_usw1_nic1" {
  for_each = { for idx, instance in google_compute_instance.core_wan_to_distro_lan_vyos_usw1 : idx => instance }

  project = var.project_id

  name      = format("%s-%s", each.value.name, "nic1")
  router    = google_compute_router.distro_lan["us-west1"].name
  region    = google_compute_router.distro_lan["us-west1"].region
  interface = google_compute_router_interface.distro_lan_appliance_nic1["us-west1"].name

  peer_asn                  = 65534
  router_appliance_instance = each.value.self_link
  peer_ip_address           = each.value.network_interface[1].network_ip
  advertised_route_priority = 200 + each.key

  depends_on = [
    google_network_connectivity_spoke.distro_lan_appliance_northbound_usw1
  ]
}

resource "google_compute_router_peer" "distro_lan_appliance_southbound_usw1_nic0" {
  for_each = { for idx, instance in google_compute_instance.distro_lan_to_access_truested_vyos_usw1 : idx => instance }

  project = var.project_id

  name      = format("%s-%s", each.value.name, "nic0")
  router    = google_compute_router.distro_lan["us-west1"].name
  region    = google_compute_router.distro_lan["us-west1"].region
  interface = google_compute_router_interface.distro_lan_appliance_nic0["us-west1"].name

  peer_asn                  = 65533
  router_appliance_instance = each.value.self_link
  peer_ip_address           = each.value.network_interface[0].network_ip
  advertised_route_priority = 100 + each.key

  depends_on = [
    google_network_connectivity_spoke.distro_lan_appliance_southbound_usw1
  ]
}

resource "google_compute_router_peer" "distro_lan_appliance_southbound_usw1_nic1" {
  for_each = { for idx, instance in google_compute_instance.distro_lan_to_access_truested_vyos_usw1 : idx => instance }

  project = var.project_id

  name      = format("%s-%s", each.value.name, "nic1")
  router    = google_compute_router.distro_lan["us-west1"].name
  region    = google_compute_router.distro_lan["us-west1"].region
  interface = google_compute_router_interface.distro_lan_appliance_nic1["us-west1"].name

  peer_asn                  = 65533
  router_appliance_instance = each.value.self_link
  peer_ip_address           = each.value.network_interface[0].network_ip
  advertised_route_priority = 200 + each.key


  depends_on = [
    google_network_connectivity_spoke.distro_lan_appliance_southbound_usw1
  ]
}

resource "google_compute_router_peer" "access_trusted_0000_appliance_usw1_nic0" {
  for_each = { for idx, instance in google_compute_instance.distro_lan_to_access_truested_vyos_usw1 : idx => instance }

  project = var.project_id

  name      = format("%s-%s", each.value.name, "nic0")
  router    = google_compute_router.access_trusted_0000["us-west1"].name
  region    = google_compute_router.access_trusted_0000["us-west1"].region
  interface = google_compute_router_interface.access_trusted_0000_appliance_nic0["us-west1"].name

  peer_asn                  = 65533
  router_appliance_instance = each.value.self_link
  peer_ip_address           = each.value.network_interface[1].network_ip
  advertised_route_priority = 100 + each.key

  depends_on = [
    google_network_connectivity_spoke.access_trusted_0000_appliance_usw1
  ]
}

resource "google_compute_router_peer" "access_trusted_0000_appliance_usw1_nic1" {
  for_each = { for idx, instance in google_compute_instance.distro_lan_to_access_truested_vyos_usw1 : idx => instance }

  project = var.project_id

  name      = format("%s-%s", each.value.name, "nic1")
  router    = google_compute_router.access_trusted_0000["us-west1"].name
  region    = google_compute_router.access_trusted_0000["us-west1"].region
  interface = google_compute_router_interface.access_trusted_0000_appliance_nic1["us-west1"].name

  peer_asn                  = 65533
  router_appliance_instance = each.value.self_link
  peer_ip_address           = each.value.network_interface[1].network_ip
  advertised_route_priority = 200 + each.key


  depends_on = [
    google_network_connectivity_spoke.access_trusted_0000_appliance_usw1
  ]
}

resource "google_compute_router_peer" "access_trusted_0001_appliance_usw1_nic0" {
  for_each = { for idx, instance in google_compute_instance.distro_lan_to_access_truested_vyos_usw1 : idx => instance }

  project = var.project_id

  name      = format("%s-%s", each.value.name, "nic0")
  router    = google_compute_router.access_trusted_0001["us-west1"].name
  region    = google_compute_router.access_trusted_0001["us-west1"].region
  interface = google_compute_router_interface.access_trusted_0001_appliance_nic0["us-west1"].name

  peer_asn                  = 65533
  router_appliance_instance = each.value.self_link
  peer_ip_address           = each.value.network_interface[2].network_ip
  advertised_route_priority = 100 + each.key

  depends_on = [
    google_network_connectivity_spoke.access_trusted_0001_appliance_usw1
  ]
}

resource "google_compute_router_peer" "access_trusted_0001_appliance_usw1_nic1" {
  for_each = { for idx, instance in google_compute_instance.distro_lan_to_access_truested_vyos_usw1 : idx => instance }

  project = var.project_id

  name      = format("%s-%s", each.value.name, "nic1")
  router    = google_compute_router.access_trusted_0001["us-west1"].name
  region    = google_compute_router.access_trusted_0001["us-west1"].region
  interface = google_compute_router_interface.access_trusted_0001_appliance_nic1["us-west1"].name

  peer_asn                  = 65533
  router_appliance_instance = each.value.self_link
  peer_ip_address           = each.value.network_interface[2].network_ip
  advertised_route_priority = 200 + each.key


  depends_on = [
    google_network_connectivity_spoke.access_trusted_0001_appliance_usw1
  ]
}

resource "google_compute_router_peer" "access_trusted_0002_appliance_usw1_nic0" {
  for_each = { for idx, instance in google_compute_instance.distro_lan_to_access_truested_vyos_usw1 : idx => instance }

  project = var.project_id

  name      = format("%s-%s", each.value.name, "nic0")
  router    = google_compute_router.access_trusted_0002["us-west1"].name
  region    = google_compute_router.access_trusted_0002["us-west1"].region
  interface = google_compute_router_interface.access_trusted_0002_appliance_nic0["us-west1"].name

  peer_asn                  = 65533
  router_appliance_instance = each.value.self_link
  peer_ip_address           = each.value.network_interface[3].network_ip
  advertised_route_priority = 100 + each.key

  depends_on = [
    google_network_connectivity_spoke.access_trusted_0002_appliance_usw1
  ]
}

resource "google_compute_router_peer" "access_trusted_0002_appliance_usw1_nic1" {
  for_each = { for idx, instance in google_compute_instance.distro_lan_to_access_truested_vyos_usw1 : idx => instance }

  project = var.project_id

  name      = format("%s-%s", each.value.name, "nic1")
  router    = google_compute_router.access_trusted_0002["us-west1"].name
  region    = google_compute_router.access_trusted_0002["us-west1"].region
  interface = google_compute_router_interface.access_trusted_0002_appliance_nic1["us-west1"].name

  peer_asn                  = 65533
  router_appliance_instance = each.value.self_link
  peer_ip_address           = each.value.network_interface[3].network_ip
  advertised_route_priority = 200 + each.key


  depends_on = [
    google_network_connectivity_spoke.access_trusted_0002_appliance_usw1
  ]
}

resource "google_pubsub_subscription" "core_wan_to_distro_lan_vyos_usw1" {
  count = length(google_compute_instance.core_wan_to_distro_lan_vyos_usw1)

  project = var.project_id
  name    = google_compute_instance.core_wan_to_distro_lan_vyos_usw1[count.index].name
  topic   = google_pubsub_topic.configuration_update_topic.name

  filter = "attributes.objectId = \"core_wan_to_distro_lan_vyos_usw1.conf\""

  ack_deadline_seconds = 30
}

resource "google_pubsub_subscription_iam_policy" "core_wan_to_distro_lan_vyos_usw1" {
  count = length(google_pubsub_subscription.core_wan_to_distro_lan_vyos_usw1)

  project      = var.project_id
  subscription = google_pubsub_subscription.core_wan_to_distro_lan_vyos_usw1[count.index].name
  policy_data  = data.google_iam_policy.subscription_subscriber.policy_data
}



resource "google_pubsub_subscription" "distro_lan_to_access_truested_vyos_usw1" {
  count   = length(google_compute_instance.distro_lan_to_access_truested_vyos_usw1)

  project = var.project_id
  name    = google_compute_instance.distro_lan_to_access_truested_vyos_usw1[count.index].name
  topic   = google_pubsub_topic.configuration_update_topic.name

  filter               = "attributes.objectId = \"distro_lan_to_access_truested_vyos_usw1.conf\""
  ack_deadline_seconds = 30
}

resource "google_pubsub_subscription_iam_policy" "distro_lan_to_access_truested_vyos_usw1" {
  count = length(google_pubsub_subscription.distro_lan_to_access_truested_vyos_usw1)

  project      = var.project_id
  subscription = google_pubsub_subscription.distro_lan_to_access_truested_vyos_usw1[count.index].name
  policy_data  = data.google_iam_policy.subscription_subscriber.policy_data
}


resource "google_storage_notification" "core_wan_to_distro_lan_vyos_usw1" {
  bucket             = google_storage_bucket.bucket.name
  payload_format     = "JSON_API_V1"
  topic              = google_pubsub_topic.configuration_update_topic.id
  event_types        = ["OBJECT_FINALIZE", "OBJECT_METADATA_UPDATE"]
  object_name_prefix = "core_wan_to_distro_lan_vyos_usw1"
  depends_on         = [google_pubsub_topic_iam_member.pubsub_notification_event]
}

resource "google_storage_notification" "distro_lan_to_access_truested_vyos_usw1" {
  bucket             = google_storage_bucket.bucket.name
  payload_format     = "JSON_API_V1"
  topic              = google_pubsub_topic.configuration_update_topic.id
  event_types        = ["OBJECT_FINALIZE", "OBJECT_METADATA_UPDATE"]
  object_name_prefix = "distro_lan_to_access_truested_vyos_usw1"
  depends_on         = [google_pubsub_topic_iam_member.pubsub_notification_event]
}

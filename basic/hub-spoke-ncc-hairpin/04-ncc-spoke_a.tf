# Instance in us-west1-a
resource "google_compute_instance" "spoke_a_us_west1_a-00" {
  name         = format("spoke-a-us-west1-a-%02d-${random_id.id.hex}", 0)
  machine_type = var.machine_type
  zone         = "us-west1-a"
  project      = var.project_id

  metadata = {
    enable-oslogin     = "FALSE"
    serial-port-enable = "TRUE"
    user-data          = var.vyos_user_data
  }
  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  can_ip_forward = true

  network_interface {
    network    = google_compute_network.spoke_a_vpc_network.id
    subnetwork = google_compute_subnetwork.spoke_a_us_west1_subnet.id
    nic_type   = "GVNIC"
  }
}


# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/network_connectivity_spoke
resource "google_network_connectivity_spoke" "spoke_a_us_west1" {
  project = var.project_id

  name     = format("spoke-a-us-west1-${random_id.id.hex}")
  hub      = google_network_connectivity_hub.spoke_a_ncc_hub.name
  location = "us-west1"

  linked_router_appliance_instances {
    site_to_site_data_transfer = true

    instances {
      virtual_machine = google_compute_instance.spoke_a_us_west1_a-00.self_link
      ip_address      = google_compute_instance.spoke_a_us_west1_a-00.network_interface[0].network_ip
    }
  }
}


# Instance in us-east4-a
resource "google_compute_instance" "spoke_a_us_east4_a-00" {
  name         = format("spoke-a-us-east4-a-%02d-${random_id.id.hex}", 0)
  machine_type = var.machine_type
  zone         = "us-east4-a"
  project      = var.project_id

  metadata = {
    enable-oslogin     = "FALSE"
    serial-port-enable = "TRUE"
    user-data          = var.vyos_user_data
  }
  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  can_ip_forward = true

  network_interface {
    network    = google_compute_network.spoke_a_vpc_network.id
    subnetwork = google_compute_subnetwork.spoke_a_us_east4_subnet.id
    nic_type   = "GVNIC"
  }
}


# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/network_connectivity_spoke
resource "google_network_connectivity_spoke" "spoke_a_us_east4" {
  project = var.project_id

  name     = format("spoke-a-us-east4-${random_id.id.hex}")
  hub      = google_network_connectivity_hub.spoke_a_ncc_hub.name
  location = "us-east4"

  linked_router_appliance_instances {
    site_to_site_data_transfer = true

    instances {
      virtual_machine = google_compute_instance.spoke_a_us_east4_a-00.self_link
      ip_address      = google_compute_instance.spoke_a_us_east4_a-00.network_interface[0].network_ip
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_peer
resource "google_compute_router_peer" "spoke_a_us_west1_a-00-to-nic0" {
  project = var.project_id

  name      = format("spoke-a-us-west1-a-%02d-to-nic%02d-${random_id.id.hex}", 0, 0)
  router    = google_compute_router.spoke_a_us_west1_router.name
  region    = google_compute_router.spoke_a_us_west1_router.region
  interface = google_compute_router_interface.router_interface-nic0-us-west1.name
  #   format("%s-%s-%s", var.config_map[each.value.network].prefix, format("nic%02d", 0), local.random_id.hex)

  #   peer_asn = 
  peer_asn = ((google_compute_router.spoke_a_us_west1_router.bgp[0].asn * 100) + 4200000000) + 1


  router_appliance_instance = google_compute_instance.spoke_a_us_west1_a-00.self_link
  peer_ip_address           = google_compute_instance.spoke_a_us_west1_a-00.network_interface[0].network_ip
  advertised_route_priority = 100

}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_peer
resource "google_compute_router_peer" "spoke_a_us_west1_a-00-to-nic1" {
  project = var.project_id

  name      = format("spoke-a-us-west1-a-%02d-to-nic%02d-${random_id.id.hex}", 0, 1)
  router    = google_compute_router.spoke_a_us_west1_router.name
  region    = google_compute_router.spoke_a_us_west1_router.region
  interface = google_compute_router_interface.router_interface-nic1-us-west1.name
  #   format("%s-%s-%s", var.config_map[each.value.network].prefix, format("nic%02d", 0), local.random_id.hex)

  #   peer_asn = 
  peer_asn = ((google_compute_router.spoke_a_us_west1_router.bgp[0].asn * 100) + 4200000000) + 1


  router_appliance_instance = google_compute_instance.spoke_a_us_west1_a-00.self_link
  peer_ip_address           = google_compute_instance.spoke_a_us_west1_a-00.network_interface[0].network_ip
  advertised_route_priority = 100

}

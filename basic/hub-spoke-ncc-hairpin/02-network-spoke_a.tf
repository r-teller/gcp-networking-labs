# Google Compute Network - https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network
resource "google_compute_network" "spoke_a_vpc_network" {
  name                    = "spoke-a-custom-vpc-${random_id.id.hex}"
  auto_create_subnetworks = false
  project                 = var.project_id
}

# Google Compute Subnetwork - https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
resource "google_compute_subnetwork" "spoke_a_us_west1_subnet" {
  name          = "spoke-a-us-west1-subnet-${random_id.id.hex}"
  ip_cidr_range = "10.0.0.0/24"
  region        = "us-west1"
  network       = google_compute_network.spoke_a_vpc_network.id
  project       = var.project_id

  secondary_ip_range {
    range_name    = "spoke-a-us-west1-gke-pods"
    ip_cidr_range = "11.0.0.0/16"
  }

  secondary_ip_range {
    range_name    = "spoke-a-us-west1-gke-services"
    ip_cidr_range = "11.1.0.0/24"
  }
}

resource "google_compute_router" "spoke_a_us_west1_router" {
  name    = "spoke-a-us-west1-router-${random_id.id.hex}"
  region  = "us-west1"
  network = google_compute_network.spoke_a_vpc_network.id
  project = var.project_id
  bgp {
    asn = 65000
  }
}

# # https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_interface
# resource "google_compute_router_interface" "router_interface-nic0-us-west1" {
#   project = var.project_id

#   name               = "spoke-a-us-west1-router-nic0-${random_id.id.hex}"
#   router             = google_compute_router.spoke_a_us_west1_router.name
#   region             = google_compute_router.spoke_a_us_west1_router.region
#   private_ip_address = cidrhost(google_compute_subnetwork.spoke_a_us_west1_subnet.ip_cidr_range, -3)
#   subnetwork         = google_compute_subnetwork.spoke_a_us_west1_subnet.self_link
# }

# # https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_interface
# resource "google_compute_router_interface" "router_interface-nic1-us-west1" {
#   project = var.project_id

#   name               = "spoke-a-us-west1-router-nic1-${random_id.id.hex}"
#   router             = google_compute_router.spoke_a_us_west1_router.name
#   region             = google_compute_router.spoke_a_us_west1_router.region
#   redundant_interface = google_compute_router_interface.router_interface-nic0-us-west1.name
#   private_ip_address = cidrhost(google_compute_subnetwork.spoke_a_us_west1_subnet.ip_cidr_range, -4)
#   subnetwork         = google_compute_subnetwork.spoke_a_us_west1_subnet.self_link
# }

# Google Compute Subnetwork - https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
resource "google_compute_subnetwork" "spoke_a_us_east4_subnet" {
  name          = "spoke-a-us-east4-subnet-${random_id.id.hex}"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-east4"
  network       = google_compute_network.spoke_a_vpc_network.id
  project       = var.project_id

  secondary_ip_range {
    range_name    = "spoke-a-us-east4-gke-pods"
    ip_cidr_range = "11.2.0.0/16"
  }

  secondary_ip_range {
    range_name    = "spoke-a-us-east4-gke-services"
    ip_cidr_range = "11.3.0.0/24"
  }
}

resource "google_compute_router" "spoke_a_us_east4_router" {
  name    = "spoke-a-us-east4-router-${random_id.id.hex}"
  region  = "us-east4"
  network = google_compute_network.spoke_a_vpc_network.id
  project = var.project_id
  bgp {
    asn = 65001
  }
}

# Google Compute Router Interface for NIC0 - us-east4
resource "google_compute_router_interface" "router_interface-nic0-us-east4" {
  project = var.project_id

  name               = "spoke-a-us-east4-router-nic0-${random_id.id.hex}"
  router             = google_compute_router.spoke_a_us_east4_router.name
  region             = google_compute_router.spoke_a_us_east4_router.region
  private_ip_address = cidrhost(google_compute_subnetwork.spoke_a_us_east4_subnet.ip_cidr_range, -3)
  subnetwork         = google_compute_subnetwork.spoke_a_us_east4_subnet.self_link
}

# Google Compute Router Interface for NIC1 - us-east4
resource "google_compute_router_interface" "router_interface-nic1-us-east4" {
  project = var.project_id

  name               = "spoke-a-us-east4-router-nic1-${random_id.id.hex}"
  router             = google_compute_router.spoke_a_us_east4_router.name
  region             = google_compute_router.spoke_a_us_east4_router.region
  redundant_interface = google_compute_router_interface.router_interface-nic0-us-east4.name
  private_ip_address = cidrhost(google_compute_subnetwork.spoke_a_us_east4_subnet.ip_cidr_range, -4)
  subnetwork         = google_compute_subnetwork.spoke_a_us_east4_subnet.self_link
}

# Google Compute Global Address - https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address
resource "google_compute_global_address" "spoke_a_global_address" {
  name          = "spoke-a-global-address-${random_id.id.hex}"
  project       = var.project_id
  network       = google_compute_network.spoke_a_vpc_network.id
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  ip_version    = "IPV4"
  prefix_length = 21
  address       = "10.0.224.0"
}

# Google Service Networking Connection - https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_networking_connection
resource "google_service_networking_connection" "spoke_a_service_connection" {
  network                 = google_compute_network.spoke_a_vpc_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.spoke_a_global_address.name]
}

# Google Compute Network Peering Routes Config - https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering_routes_config
resource "google_compute_network_peering_routes_config" "spoke_a_peering_routes" {
  peering              = google_service_networking_connection.spoke_a_service_connection.peering
  network              = google_compute_network.spoke_a_vpc_network.name
  project              = var.project_id
  export_custom_routes = true
  import_custom_routes = false
}

# Allow all traffic from RFC1918 and GCP IAP ranges
resource "google_compute_firewall" "spoke_a_firewall_rfc1918_iap" {
  name    = "spoke-a-firewall-rfc1918-iap"
  network = google_compute_network.spoke_a_vpc_network.id
  project = var.project_id

  source_ranges = [
    "10.0.0.0/8",      # RFC1918 range
    "172.16.0.0/12",   # RFC1918 range
    "192.168.0.0/16",  # RFC1918 range
    "35.235.240.0/20", # GCP IAP range
  ]
  
  allow {
    protocol = "all"
  }
}

# Google Compute Network Connectivity Hub - https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/network_connectivity_hub
resource "google_network_connectivity_hub" "spoke_a_ncc_hub" {
  project = var.project_id
  name    = format("spoke-a-ncc-hub-%s", random_id.id.hex)
  depends_on = [
    google_compute_network.spoke_a_vpc_network
  ]
}


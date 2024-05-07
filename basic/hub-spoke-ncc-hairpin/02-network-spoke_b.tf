# Google Compute Network - https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network
resource "google_compute_network" "spoke_b_vpc_network" {
  name                    = "spoke-b-custom-vpc-${random_id.id.hex}"
  auto_create_subnetworks = false
  project                 = var.project_id
}

# Google Compute Subnetwork - https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
resource "google_compute_subnetwork" "spoke_b_us_west1_subnet" {
  name          = "spoke-b-us-west1-subnet-${random_id.id.hex}"
  ip_cidr_range = "10.1.0.0/24"
  region        = "us-west1"
  network       = google_compute_network.spoke_b_vpc_network.id
  project       = var.project_id

  secondary_ip_range {
    range_name    = "spoke-b-us-west1-gke-pods"
    ip_cidr_range = "11.0.0.0/16"
  }

  secondary_ip_range {
    range_name    = "spoke-b-us-west1-gke-services"
    ip_cidr_range = "11.1.0.0/24"
  }
}

resource "google_compute_router" "spoke_b_us_west1_router" {
  name    = "spoke-b-us-west1-router-${random_id.id.hex}"
  region  = "us-west1"
  network = google_compute_network.spoke_b_vpc_network.id
  project = var.project_id
  bgp {
    asn = 65050
  }
}

# Google Compute Subnetwork - https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
resource "google_compute_subnetwork" "spoke_b_us_east4_subnet" {
  name          = "spoke-b-us-east4-subnet-${random_id.id.hex}"
  ip_cidr_range = "10.1.1.0/24"
  region        = "us-east4"
  network       = google_compute_network.spoke_b_vpc_network.id
  project       = var.project_id

  secondary_ip_range {
    range_name    = "spoke-b-us-east4-gke-pods"
    ip_cidr_range = "11.2.0.0/16"
  }

  secondary_ip_range {
    range_name    = "spoke-b-us-east4-gke-services"
    ip_cidr_range = "11.3.0.0/24"
  }
}

resource "google_compute_router" "spoke_b_us_east4_router" {
  name    = "spoke-b-us-east4-router-${random_id.id.hex}"
  region  = "us-east4"
  network = google_compute_network.spoke_b_vpc_network.id
  project = var.project_id
  bgp {
    asn = 65051
  }
}

# Google Compute Global Address - https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address
resource "google_compute_global_address" "spoke_b_global_address" {
  name          = "spoke-b-global-address-${random_id.id.hex}"
  project       = var.project_id
  network       = google_compute_network.spoke_b_vpc_network.id
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  ip_version    = "IPV4"
  prefix_length = 21
  address       = "10.1.224.0"
}

# Google Service Networking Connection - https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_networking_connection
resource "google_service_networking_connection" "spoke_b_service_connection" {
  network                 = google_compute_network.spoke_b_vpc_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.spoke_b_global_address.name]
}

# Google Compute Network Peering Routes Config - https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering_routes_config
resource "google_compute_network_peering_routes_config" "spoke_b_peering_routes" {
  peering              = google_service_networking_connection.spoke_b_service_connection.peering
  network              = google_compute_network.spoke_b_vpc_network.name
  project              = var.project_id
  export_custom_routes = true
  import_custom_routes = false
}

# Allow all traffic from RFC1918 and GCP IAP ranges
resource "google_compute_firewall" "spoke_b_firewall_rfc1918_iap" {
  name    = "spoke-b-firewall-rfc1918-iap"
  network = google_compute_network.spoke_b_vpc_network.id
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
resource "google_network_connectivity_hub" "spoke_b_ncc_hub" {
  project = var.project_id
  name    = format("spoke-b-ncc-hub-%s", random_id.id.hex)
  depends_on = [
    google_compute_network.spoke_b_vpc_network
  ]
}

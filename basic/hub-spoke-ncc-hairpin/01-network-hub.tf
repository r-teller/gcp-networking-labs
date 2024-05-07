# Google Compute Network - https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network
resource "google_compute_network" "hub_vpc_network" {
  name                            = "hub-custom-vpc-${random_id.id.hex}"
  auto_create_subnetworks         = false
  delete_default_routes_on_create = false
  project                         = var.project_id
}

# Google Compute Subnetwork - https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
resource "google_compute_subnetwork" "hub_us_west1_subnet" {
  name          = "hub-us-west1-subnet-${random_id.id.hex}"
  ip_cidr_range = "192.168.0.0/24"
  region        = "us-west1"
  network       = google_compute_network.hub_vpc_network.id
  project       = var.project_id
}

# Google Compute Subnetwork - https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
resource "google_compute_subnetwork" "hub_us_east4_subnet" {
  name          = "hub-us-east4-subnet-${random_id.id.hex}"
  ip_cidr_range = "192.168.1.0/24"
  region        = "us-east4"
  network       = google_compute_network.hub_vpc_network.id
  project       = var.project_id
}

# Allow all traffic from RFC1918 and GCP IAP ranges
resource "google_compute_firewall" "hub_firewall_rfc1918_iap" {
  name    = "hub-firewall-rfc1918-iap"
  network = google_compute_network.hub_vpc_network.id
  project = var.project_id

  source_ranges = [
    "10.0.0.0/8",      # RFC1918 range
    "172.16.0.0/12",   # RFC1918 range
    "192.168.0.0/16",  # RFC1918 range
    "35.235.240.0/20", # GCP IAP range
  ]

#   destination_ranges = []
  allow {
    protocol = "all"
  }
}


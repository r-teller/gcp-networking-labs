# Google Compute Network Peering - https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering
# VPC Peering between hub and spoke-a
resource "google_compute_network_peering" "hub_to_spoke_a" {
  name         = "hub-to-spoke-a-peering"
  network      = google_compute_network.hub_vpc_network.id
  peer_network = google_compute_network.spoke_a_vpc_network.id
  export_custom_routes = true
  import_custom_routes = true
  export_subnet_routes_with_public_ip = false
  import_subnet_routes_with_public_ip = false
}

# Google Compute Network Peering - https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering
resource "google_compute_network_peering" "spoke_a_to_hub" {
  name         = "spoke-a-to-hub-peering"
  network      = google_compute_network.spoke_a_vpc_network.id
  peer_network = google_compute_network.hub_vpc_network.id
  export_custom_routes = true
  import_custom_routes = true
  export_subnet_routes_with_public_ip = false
  import_subnet_routes_with_public_ip = false
}

# Google Compute Network Peering - https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering
# VPC Peering between hub and spoke-b
resource "google_compute_network_peering" "hub_to_spoke_b" {
  name         = "hub-to-spoke-b-peering"
  network      = google_compute_network.hub_vpc_network.id
  peer_network = google_compute_network.spoke_b_vpc_network.id
  export_custom_routes = true
  import_custom_routes = true
  export_subnet_routes_with_public_ip = false
  import_subnet_routes_with_public_ip = false
}

# Google Compute Network Peering - https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering
resource "google_compute_network_peering" "spoke_b_to_hub" {
  name         = "spoke-b-to-hub-peering"
  network      = google_compute_network.spoke_b_vpc_network.id
  peer_network = google_compute_network.hub_vpc_network.id
  export_custom_routes = true
  import_custom_routes = true
  export_subnet_routes_with_public_ip = false
  import_subnet_routes_with_public_ip = false
}


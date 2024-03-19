output "ncc_hub" {
  value = try(google_network_connectivity_hub.connectivity_hub[0], null)
}

output "network" {
  value = google_compute_network.network
}

output "subnetworks" {
  value = google_compute_subnetwork.subnetwork
}

output "private_service_ranges" {
  value = google_compute_global_address.global_address
}


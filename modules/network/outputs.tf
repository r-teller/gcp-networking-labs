output "ncc_hub" {
  value = try(google_network_connectivity_hub.connectivity_hub[0], null)
}

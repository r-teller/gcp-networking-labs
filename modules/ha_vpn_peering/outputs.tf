
output "vpn_tunnels" {
  # value = google_compute_vpn_tunnel.vpn_tunnels
  value = {
    vpn_tunnels  = google_compute_vpn_tunnel.vpn_tunnels
    map          = local.map,
    distinct_map = local.distinct_map
  }
}


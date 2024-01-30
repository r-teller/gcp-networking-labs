
output "vpn_tunnels" {
  value = { for k, v in merge(values(local.map).*.tunnels...) : k => {
    local_gateway_ip  = one([for x in google_compute_ha_vpn_gateway.ha_vpn_gateways[v.parent_key].vpn_interfaces : x.ip_address if x.id == v.vpn_gateway_interface])
    local_bgp_ip      = cidrhost(cidrsubnet("169.254.0.0/16", 14, random_integer.tunnel_bits[v.self_key].result), 2)
    local_bgp_asn     = google_compute_router.routers[v.parent_key].bgp[0].asn
    remote_gateway_ip = one([for x in google_compute_external_vpn_gateway.external_vpn_gateways[v.parent_key].interface : x.ip_address if x.id == v.vpn_gateway_interface])
    remote_bgp_ip     = cidrhost(cidrsubnet("169.254.0.0/16", 14, random_integer.tunnel_bits[v.self_key].result), 1)
    remote_bgp_asn    = v.peer_asn
    secret            = random_id.secret.id
    }
  }
}


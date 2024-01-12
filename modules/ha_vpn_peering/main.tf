resource "random_id" "seed" {
  byte_length = 2
}

resource "random_id" "secret" {
  byte_length = 8
}

resource "random_integer" "tunnel_bits" {
  for_each = local.tunnel_map
  min      = 0
  max      = 4095
  seed     = format("%s-%s", random_id.seed.hex, each.key)
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_ha_vpn_gateway
resource "google_compute_ha_vpn_gateway" "ha_vpn_gateways" {
  for_each = local.distinct_map

  provider = google-beta
  name     = each.value.name
  project  = var.project_id
  region   = each.value.region
  network  = each.value.network
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router
resource "google_compute_router" "routers" {
  for_each = local.distinct_map

  project = var.project_id

  name    = each.value.name
  network = each.value.network

  region = each.value.region
  bgp {
    asn               = each.value.asn
    advertise_mode    = "CUSTOM"
    advertised_groups = lookup(var.config_map[each.value.key], "advertise_local_subnets", false) ? ["ALL_SUBNETS"] : []

    dynamic "advertised_ip_ranges" {
      for_each = try(var.config_map[each.value.key].summary_ip_ranges[each.value.region], [])
      content {
        range = advertised_ip_ranges.value
      }
    }
  }
}

resource "google_compute_vpn_tunnel" "vpn_tunnels" {
  for_each = merge(values(local.map).*.tunnels...)

  project = var.project_id

  name = format("vpn-%04d-%s-%s-%02d-%s",
    (
      each.value.is_hub
      ? random_integer.tunnel_bits[each.value.self_key].result
      : random_integer.tunnel_bits[each.value.peer_key].result
    ),
    var.config_map[each.value.key].prefix,
    module.utils.region_short_name_map[each.value.region],
    each.value.vpn_gateway_interface,
    local.random_id.hex,
  )

  region                          = each.value.region
  router                          = each.value.router
  peer_external_gateway_interface = null
  peer_gcp_gateway                = each.value.peer_name
  vpn_gateway_interface           = each.value.vpn_gateway_interface
  ike_version                     = 2
  shared_secret                   = random_id.secret.id
  vpn_gateway                     = each.value.self_name

  depends_on = [
    google_compute_router.routers,
    google_compute_ha_vpn_gateway.ha_vpn_gateways,
  ]
}


resource "google_compute_router_interface" "router_interfaces" {
  for_each = merge(values(local.map).*.tunnels...)

  project = var.project_id

  name = format("vpn-%04d-%s-%s-%02d-%s",
    (
      each.value.is_hub
      ? random_integer.tunnel_bits[each.value.self_key].result
      : random_integer.tunnel_bits[each.value.peer_key].result
    ),
    var.config_map[each.value.key].prefix,
    module.utils.region_short_name_map[each.value.region],
    each.value.vpn_gateway_interface,
    local.random_id.hex,
  )

  region = each.value.region
  router = each.value.router
  ip_range = (
    each.value.is_hub
    ? format("%s/%d", cidrhost(cidrsubnet("169.254.0.0/16", 14, random_integer.tunnel_bits[each.value.self_key].result), 1), 30)
    : format("%s/%d", cidrhost(cidrsubnet("169.254.0.0/16", 14, random_integer.tunnel_bits[each.value.peer_key].result), 2), 30)
  )

  vpn_tunnel = format("vpn-%04d-%s-%s-%02d-%s",
    (
      each.value.is_hub
      ? random_integer.tunnel_bits[each.value.self_key].result
      : random_integer.tunnel_bits[each.value.peer_key].result
    ),
    var.config_map[each.value.key].prefix,
    module.utils.region_short_name_map[each.value.region],
    each.value.vpn_gateway_interface,
    local.random_id.hex,
  )

  depends_on = [
    google_compute_router.routers,
    google_compute_vpn_tunnel.vpn_tunnels,
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_peer
resource "google_compute_router_peer" "router_peers" {
  for_each = merge(values(local.map).*.tunnels...)

  project = var.project_id

  name = format("vpn-%04d-%s-%s-%02d-%s",
    (
      each.value.is_hub
      ? random_integer.tunnel_bits[each.value.self_key].result
      : random_integer.tunnel_bits[each.value.peer_key].result
    ),
    var.config_map[each.value.key].prefix,
    module.utils.region_short_name_map[each.value.region],
    each.value.vpn_gateway_interface,
    local.random_id.hex,
  )

  region                    = each.value.region
  router                    = each.value.router
  peer_asn                  = each.value.peer_asn
  advertised_route_priority = 200
  peer_ip_address = (
    each.value.is_hub
    ? cidrhost(cidrsubnet("169.254.0.0/16", 14, random_integer.tunnel_bits[each.value.self_key].result), 2)
    : cidrhost(cidrsubnet("169.254.0.0/16", 14, random_integer.tunnel_bits[each.value.peer_key].result), 1)
  )

  interface = format("vpn-%04d-%s-%s-%02d-%s",
    (
      each.value.is_hub
      ? random_integer.tunnel_bits[each.value.self_key].result
      : random_integer.tunnel_bits[each.value.peer_key].result
    ),
    var.config_map[each.value.key].prefix,
    module.utils.region_short_name_map[each.value.region],
    each.value.vpn_gateway_interface,
    local.random_id.hex,
  )

  depends_on = [
    google_compute_router.routers,
    google_compute_router_interface.router_interfaces,
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/network_connectivity_spoke
resource "google_network_connectivity_spoke" "network_connectivity_spoke" {
  for_each = { for k, v in local.distinct_map : k => v if(
    v.is_hub &&
    v.use_ncc_hub &&
    v.tunnel_count > 0
  ) }

  project = var.project_id
  name    = each.value.name

  location = each.value.region

  # hub = format("%s-%s", var.config_map[each.value.key].prefix, local.random_id.hex)
  hub = each.value.network

  linked_vpn_tunnels {
    site_to_site_data_transfer = true
    uris = [
    for k, v in google_compute_vpn_tunnel.vpn_tunnels : v.self_link if v.region == each.value.region && endswith(v.vpn_gateway, each.value.name)]
  }

  depends_on = [
    google_compute_router.routers,
    google_compute_router_interface.router_interfaces,
    google_compute_vpn_tunnel.vpn_tunnels
  ]
}

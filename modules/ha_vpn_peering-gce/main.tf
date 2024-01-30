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

  project = var.project_id

  provider = google-beta
  name     = each.value.name
  region   = each.value.region
  network  = each.value.network
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_external_vpn_gateway
resource "google_compute_external_vpn_gateway" "external_vpn_gateways" {
  for_each = local.map

  project = var.project_id
  name    = each.value.name
  redundancy_type = {
    1 = "SINGLE_IP_INTERNALLY_REDUNDANT",
    2 = "TWO_IPS_REDUNDANCY",
    4 = "FOUR_IPS_REDUNDANCY",
  }[length(each.value.peer_addresses)]

  dynamic "interface" {
    for_each = each.value.peer_addresses
    content {
      id         = interface.key
      ip_address = interface.value
    }

  }
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
    random_integer.tunnel_bits[each.value.self_key].result,
    var.config_map[each.value.key].prefix,
    module.utils.region_short_name_map[each.value.region],
    each.value.vpn_gateway_interface,
    local.random_id.hex,
  )

  region = each.value.region
  router = each.value.router

  peer_external_gateway           = each.value.self_name
  peer_external_gateway_interface = each.value.vpn_gateway_interface
  vpn_gateway_interface           = each.value.vpn_gateway_interface
  ike_version                     = 2
  shared_secret                   = random_id.secret.id
  vpn_gateway                     = each.value.self_name

  depends_on = [
    google_compute_router.routers,
    google_compute_ha_vpn_gateway.ha_vpn_gateways,
  ]

  lifecycle {
    replace_triggered_by = [google_compute_external_vpn_gateway.external_vpn_gateways]
  }
}

resource "google_compute_router_interface" "router_interfaces" {
  for_each = merge(values(local.map).*.tunnels...)

  project = var.project_id

  name = format("vpn-%04d-%s-%s-%02d-%s",
    random_integer.tunnel_bits[each.value.self_key].result,
    var.config_map[each.value.key].prefix,
    module.utils.region_short_name_map[each.value.region],
    each.value.vpn_gateway_interface,
    local.random_id.hex,
  )

  region   = each.value.region
  router   = each.value.router
  ip_range = format("%s/%d", cidrhost(cidrsubnet("169.254.0.0/16", 14, random_integer.tunnel_bits[each.value.self_key].result), 2), 30)

  vpn_tunnel = format("vpn-%04d-%s-%s-%02d-%s",
    random_integer.tunnel_bits[each.value.self_key].result,
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
    random_integer.tunnel_bits[each.value.self_key].result,
    var.config_map[each.value.key].prefix,
    module.utils.region_short_name_map[each.value.region],
    each.value.vpn_gateway_interface,
    local.random_id.hex,
  )

  region                    = each.value.region
  router                    = each.value.router
  peer_asn                  = each.value.peer_asn
  advertised_route_priority = 200
  peer_ip_address           = cidrhost(cidrsubnet("169.254.0.0/16", 14, random_integer.tunnel_bits[each.value.self_key].result), 1)

  interface = format("vpn-%04d-%s-%s-%02d-%s",
    random_integer.tunnel_bits[each.value.self_key].result,
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

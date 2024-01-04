resource "random_id" "on_prem_wan-to-core_wan-seed" {
  byte_length = 2
}

resource "random_integer" "on_prem_wan-to-core_wan" {
  for_each = { for k, v in merge(values(local.on_prem_wan-to-core_wan-map).*.tunnels...) : k => {} if v.is_local }
  min      = 0
  max      = 4095
  seed     = format("%s-%s", random_id.on_prem_wan-to-core_wan-seed.hex, each.key)
}

locals {
  on_prem_wan-to-core_wan = {
    regions = ["us-east4","us-west1"]
    networks = {
      local  = "on_prem_wan",
      remote = "core_wan",
    }
    tunnel_count = 2
  }

  _on_prem_wan-to-core_wan-map = {
    for x in setproduct(values(local.on_prem_wan-to-core_wan.networks), local.on_prem_wan-to-core_wan.regions) :
    join("-", [x[0], x[1]]) => {
      asn      = local._networks[x[0]].asn
      key      = x[0]
      is_local = local.on_prem_wan-to-core_wan.networks.local == x[0]
      name = format("vpn-%s-%s-%s-%s",
        random_id.on_prem_wan-to-core_wan-seed.hex,
        local._networks[x[0]].prefix,
        local._regions[x[1]],
        random_id.id.hex
      )
      network   = format("%s-%s", local._networks[x[0]].prefix, random_id.id.hex)
      prefix    = local._networks[x[0]].prefix
      region    = x[1]
      is_remote = local.on_prem_wan-to-core_wan.networks.remote == x[0]
    }
  }

  on_prem_wan-to-core_wan-map = { for k, v in local._on_prem_wan-to-core_wan-map : k => merge(v, {
    tunnels : { for idx in range(local.on_prem_wan-to-core_wan.tunnel_count) :
      format("%s-%02d", k, idx) => {
        name = format("vpn-%s-%s-%s-%02d-%s",
          random_id.on_prem_wan-to-core_wan-seed.hex,
          local._networks[v.key].prefix,
          local._regions[v.region],
          idx,
          random_id.id.hex,
        )
        is_local = v.is_local
        region   = v.region
        router   = v.name
        self_key = format("%s-%02d", k, idx)
        peer_key = format("%s-%s-%02d", (
          v.is_local
          ? local.on_prem_wan-to-core_wan.networks.remote
          : local.on_prem_wan-to-core_wan.networks.local
        ), v.region, idx)
        peer_asn = (
          v.is_local
          ? local._networks[local.on_prem_wan-to-core_wan.networks.remote].asn
          : local._networks[local.on_prem_wan-to-core_wan.networks.local].asn
        )
        self_name = v.name
        peer_name = (
          v.is_local
          ? format("vpn-%s-%s-%s-%s",
            random_id.on_prem_wan-to-core_wan-seed.hex,
            local._networks[local.on_prem_wan-to-core_wan.networks.remote].prefix,
            local._regions[v.region],
            random_id.id.hex
          )
          : format("vpn-%s-%s-%s-%s",
            random_id.on_prem_wan-to-core_wan-seed.hex,
            local._networks[local.on_prem_wan-to-core_wan.networks.local].prefix,
            local._regions[v.region],
            random_id.id.hex
          )
        )
        vpn_gateway_interface = idx
        vpn_gateway           = v.name
      }
    }
    })
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_ha_vpn_gateway
resource "google_compute_ha_vpn_gateway" "on_prem_wan-to-core_wan" {
  for_each = local.on_prem_wan-to-core_wan-map

  provider = google-beta
  name     = each.value.name
  project  = var.project_id
  region   = each.value.region
  network  = each.value.network

  depends_on = [
    google_compute_network.on_prem_wan,
    google_compute_network.core_wan,
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router
resource "google_compute_router" "on_prem_wan-to-core_wan" {
  for_each = local.on_prem_wan-to-core_wan-map

  project = var.project_id

  name    = each.value.name
  network = each.value.network

  region = each.value.region
  bgp {
    asn               = each.value.asn
    advertise_mode    = "CUSTOM"
    advertised_groups = lookup(local._networks[each.value.key], "advertise_local_subnets", false) ? ["ALL_SUBNETS"] : []

    dynamic "advertised_ip_ranges" {
      for_each = try(local._networks[each.value.key].summary_ip_ranges[each.value.region], [])
      content {
        range = advertised_ip_ranges.value
      }
    }
  }

  depends_on = [
    google_compute_ha_vpn_gateway.on_prem_wan-to-core_wan,
  ]
}

resource "google_compute_vpn_tunnel" "on_prem_wan-to-core_wan" {
  for_each = merge(values(local.on_prem_wan-to-core_wan-map).*.tunnels...)

  project = var.project_id

  name                            = each.value.name
  region                          = each.value.region
  router                          = each.value.router
  peer_external_gateway_interface = null
  peer_gcp_gateway                = each.value.peer_name
  vpn_gateway_interface           = each.value.vpn_gateway_interface
  ike_version                     = 2
  shared_secret                   = random_id.secret.id
  vpn_gateway                     = each.value.self_name

  depends_on = [
    google_compute_ha_vpn_gateway.on_prem_wan-to-core_wan,
    google_compute_router.on_prem_wan-to-core_wan,
  ]
}

resource "google_compute_router_interface" "on_prem_wan-to-core_wan" {
  for_each = merge(values(local.on_prem_wan-to-core_wan-map).*.tunnels...)

  project = var.project_id

  region = each.value.region
  name   = each.value.name
  router = each.value.router
  ip_range = (
    each.value.is_local
    ? format("%s/%d", cidrhost(cidrsubnet("169.254.0.0/16", 14, random_integer.on_prem_wan-to-core_wan[each.value.self_key].result), 1), 30)
    : format("%s/%d", cidrhost(cidrsubnet("169.254.0.0/16", 14, random_integer.on_prem_wan-to-core_wan[each.value.peer_key].result), 2), 30)
  )

  vpn_tunnel = each.value.name

  depends_on = [
    google_compute_ha_vpn_gateway.on_prem_wan-to-core_wan,
    google_compute_router.on_prem_wan-to-core_wan,
    google_compute_vpn_tunnel.on_prem_wan-to-core_wan,
  ]
}

resource "google_compute_router_peer" "on_prem_wan-to-core_wan" {
  for_each = merge(values(local.on_prem_wan-to-core_wan-map).*.tunnels...)

  project = var.project_id

  name     = each.value.name
  region   = each.value.region
  router   = each.value.router
  peer_asn = each.value.peer_asn
  peer_ip_address = (
    each.value.is_local
    ? cidrhost(cidrsubnet("169.254.0.0/16", 14, random_integer.on_prem_wan-to-core_wan[each.value.self_key].result), 2)
    : cidrhost(cidrsubnet("169.254.0.0/16", 14, random_integer.on_prem_wan-to-core_wan[each.value.peer_key].result), 1)
  )
  interface = each.value.name

  depends_on = [
    google_compute_ha_vpn_gateway.on_prem_wan-to-core_wan,
    google_compute_router.on_prem_wan-to-core_wan,
    google_compute_vpn_tunnel.on_prem_wan-to-core_wan,
    google_compute_router_interface.on_prem_wan-to-core_wan,
  ]
}

resource "google_network_connectivity_spoke" "core_wan-to-on_prem_wan" {
  for_each = { for k, v in google_compute_ha_vpn_gateway.on_prem_wan-to-core_wan : k => v if startswith(k, "core_wan") }

  project = var.project_id

  name = each.value.name

  location = each.value.region

  hub = google_network_connectivity_hub.core_wan.id

  linked_vpn_tunnels {
    site_to_site_data_transfer = true
    uris                       = [for k, v in google_compute_vpn_tunnel.on_prem_wan-to-core_wan : v.self_link if v.region == each.value.region && endswith(v.vpn_gateway, each.value.name)]
  }

  depends_on = [
    google_compute_router.core_wan,
    google_compute_vpn_tunnel.on_prem_wan-to-core_wan
  ]
}


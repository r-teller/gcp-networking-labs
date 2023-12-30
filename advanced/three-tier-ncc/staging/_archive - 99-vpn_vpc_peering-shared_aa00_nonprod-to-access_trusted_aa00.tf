resource "random_id" "shared_aa00_nonprod-to-access_trusted_aa00-seed" {
  byte_length = 2
}

resource "random_integer" "shared_aa00_nonprod-to-access_trusted_aa00" {
  for_each = { for k, v in merge(values(local.shared_aa00_nonprod-to-access_trusted_aa00-map).*.tunnels...) : k => {} if v.is_local }
  min      = 0
  max      = 4095
  seed     = format("%s-%s", random_id.shared_aa00_nonprod-to-access_trusted_aa00-seed.hex, each.key)
}

locals {
  access_trusted_aa00-to-shared_aa00_nonprod = {
    regions = ["us-central1"]
    networks = {
      local  = "shared_aa00_nonprod",
      remote = "access_trusted_aa00",
    }
  }  
  # shared_aa00_nonprod-to-access_trusted_aa00 = {
  #   regions = ["us-central1"]
  #   networks = {
  #     local  = "shared_aa00_nonprod",
  #     remote = "access_trusted_aa00",
  #   }
  # }

  _shared_aa00_nonprod-to-access_trusted_aa00-map = {
    for x in setproduct(values(local.shared_aa00_nonprod-to-access_trusted_aa00.networks), local.shared_aa00_nonprod-to-access_trusted_aa00.regions) :
    join("-", [x[0], x[1]]) => {
      asn      = local._networks[x[0]].asn
      key      = x[0]
      is_local = local.shared_aa00_nonprod-to-access_trusted_aa00.networks.local == x[0]
      name = format("vpn-%s-%s-%s-%s",
        random_id.shared_aa00_nonprod-to-access_trusted_aa00-seed.hex,
        local._networks[x[0]].prefix,
        local._regions[x[1]],
        random_id.id.hex
      )
      network   = format("%s-%s", local._networks[x[0]].prefix, random_id.id.hex)
      prefix    = local._networks[x[0]].prefix
      region    = x[1]
      is_remote = local.shared_aa00_nonprod-to-access_trusted_aa00.networks.remote == x[0]
    }
  }

  shared_aa00_nonprod-to-access_trusted_aa00-map = { for k, v in local._shared_aa00_nonprod-to-access_trusted_aa00-map : k => merge(v, {
    tunnels : { for idx in range(2) :
      format("%s-%02d", k, idx) => {
        name = format("vpn-%s-%s-%s-%02d-%s",
          random_id.shared_aa00_nonprod-to-access_trusted_aa00-seed.hex,
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
          ? local.shared_aa00_nonprod-to-access_trusted_aa00.networks.remote
          : local.shared_aa00_nonprod-to-access_trusted_aa00.networks.local
        ), v.region, idx)
        peer_asn = (
          v.is_local
          ? local._networks[local.shared_aa00_nonprod-to-access_trusted_aa00.networks.remote].asn
          : local._networks[local.shared_aa00_nonprod-to-access_trusted_aa00.networks.local].asn
        )
        self_name = v.name
        peer_name = (
          v.is_local
          ? format("vpn-%s-%s-%s-%s",
            random_id.shared_aa00_nonprod-to-access_trusted_aa00-seed.hex,
            local._networks[local.shared_aa00_nonprod-to-access_trusted_aa00.networks.remote].prefix,
            local._regions[v.region],
            random_id.id.hex
          )
          : format("vpn-%s-%s-%s-%s",
            random_id.shared_aa00_nonprod-to-access_trusted_aa00-seed.hex,
            local._networks[local.shared_aa00_nonprod-to-access_trusted_aa00.networks.local].prefix,
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
resource "google_compute_ha_vpn_gateway" "shared_aa00_nonprod-to-access_trusted_aa00" {
  for_each = local.shared_aa00_nonprod-to-access_trusted_aa00-map

  provider = google-beta
  name     = each.value.name
  project  = var.project_id
  region   = each.value.region
  network  = each.value.network

  depends_on = [
    google_compute_network.shared_aa00_nonprod,
    google_compute_network.access_trusted_aa00,
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router
resource "google_compute_router" "shared_aa00_nonprod-to-access_trusted_aa00" {
  for_each = local.shared_aa00_nonprod-to-access_trusted_aa00-map

  project = var.project_id

  name    = each.value.name
  network = each.value.network

  region = each.value.region
  bgp {
    asn               = each.value.asn
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]
  }

  depends_on = [
    google_compute_ha_vpn_gateway.shared_aa00_nonprod-to-access_trusted_aa00,
  ]
}

resource "google_compute_vpn_tunnel" "shared_aa00_nonprod-to-access_trusted_aa00" {
  for_each = merge(values(local.shared_aa00_nonprod-to-access_trusted_aa00-map).*.tunnels...)

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
    google_compute_ha_vpn_gateway.shared_aa00_nonprod-to-access_trusted_aa00,
    google_compute_router.shared_aa00_nonprod-to-access_trusted_aa00,
  ]
}

resource "google_compute_router_interface" "shared_aa00_nonprod-to-access_trusted_aa00" {
  for_each = merge(values(local.shared_aa00_nonprod-to-access_trusted_aa00-map).*.tunnels...)

  project = var.project_id

  region = each.value.region
  name   = each.value.name
  router = each.value.router
  ip_range = (
    each.value.is_local
    ? format("%s/%d", cidrhost(cidrsubnet("169.254.0.0/16", 14, random_integer.shared_aa00_nonprod-to-access_trusted_aa00[each.value.self_key].result), 1), 30)
    : format("%s/%d", cidrhost(cidrsubnet("169.254.0.0/16", 14, random_integer.shared_aa00_nonprod-to-access_trusted_aa00[each.value.peer_key].result), 2), 30)
  )

  vpn_tunnel = each.value.name

  depends_on = [
    google_compute_ha_vpn_gateway.shared_aa00_nonprod-to-access_trusted_aa00,
    google_compute_router.shared_aa00_nonprod-to-access_trusted_aa00,
    google_compute_vpn_tunnel.shared_aa00_nonprod-to-access_trusted_aa00,
  ]
}

resource "google_compute_router_peer" "shared_aa00_nonprod-to-access_trusted_aa00" {
  for_each = merge(values(local.shared_aa00_nonprod-to-access_trusted_aa00-map).*.tunnels...)

  project = var.project_id

  name     = each.value.name
  region   = each.value.region
  router   = each.value.router
  peer_asn = each.value.peer_asn
  peer_ip_address = (
    each.value.is_local
    ? cidrhost(cidrsubnet("169.254.0.0/16", 14, random_integer.shared_aa00_nonprod-to-access_trusted_aa00[each.value.self_key].result), 2)
    : cidrhost(cidrsubnet("169.254.0.0/16", 14, random_integer.shared_aa00_nonprod-to-access_trusted_aa00[each.value.peer_key].result), 1)
  )
  interface = each.value.name

  depends_on = [
    google_compute_ha_vpn_gateway.shared_aa00_nonprod-to-access_trusted_aa00,
    google_compute_router.shared_aa00_nonprod-to-access_trusted_aa00,
    google_compute_vpn_tunnel.shared_aa00_nonprod-to-access_trusted_aa00,
    google_compute_router_interface.shared_aa00_nonprod-to-access_trusted_aa00,
  ]
}

resource "google_network_connectivity_spoke" "access_trusted_aa00-to-shared_aa00_nonprod" {
  for_each = { for k, v in google_compute_ha_vpn_gateway.shared_aa00_nonprod-to-access_trusted_aa00 : k => v if startswith(k, "access_trusted_aa00") }

  project = var.project_id

  name = each.value.name

  location = each.value.region

  hub = google_network_connectivity_hub.access_trusted_aa00.id

  linked_vpn_tunnels {
    site_to_site_data_transfer = true
    uris                       = [for k, v in google_compute_vpn_tunnel.shared_aa00_nonprod-to-access_trusted_aa00 : v.self_link if v.region == each.value.region && endswith(v.vpn_gateway, each.value.name)]
  }

  depends_on = [
    google_compute_router.access_trusted_aa00,
    google_compute_vpn_tunnel.shared_aa00_nonprod-to-access_trusted_aa00
  ]
}


resource "random_id" "access_trusted_aa00-to-shared_aa00_prod-seed" {
  byte_length = 2
}

resource "random_integer" "access_trusted_aa00-to-shared_aa00_prod" {
  for_each = { for k, v in merge(values(local.access_trusted_aa00-to-shared_aa00_prod-map).*.tunnels...) : k => {} if v.is_local }
  min      = 0
  max      = 4095
  seed     = format("%s-%s", random_id.access_trusted_aa00-to-shared_aa00_prod-seed.hex, each.key)
}

locals {
  access_trusted_aa00-to-shared_aa00_prod = {
    regions = ["us-central1"]
    networks = {
      local  = "shared_aa00_prod",
      remote = "access_trusted_aa00",
    }

    peerings = [
      {
        local                = "access_trusted_aa00",
        remote               = "shared_aa00_prod",
        export_custom_routes = true,
        import_custom_routes = false,
      },
      {
        local                = "shared_aa00_prod",
        remote               = "access_trusted_aa00",
        export_custom_routes = false,
        import_custom_routes = true,
      },
    ]
  }

  _access_trusted_aa00-to-shared_aa00_prod-map = {
    for x in setproduct(values(local.access_trusted_aa00-to-shared_aa00_prod.networks), local.access_trusted_aa00-to-shared_aa00_prod.regions) :
    join("-", [x[0], x[1]]) => {
      asn      = local._networks[x[0]].asn
      key      = x[0]
      is_local = local.access_trusted_aa00-to-shared_aa00_prod.networks.local == x[0]
      name = format("vpn-%s-%s-%s-%s",
        random_id.access_trusted_aa00-to-shared_aa00_prod-seed.hex,
        local._networks[x[0]].prefix,
        local._regions[x[1]],
        random_id.id.hex
      )
      network   = format("%s-%s", local._networks[x[0]].prefix, random_id.id.hex)
      prefix    = local._networks[x[0]].prefix
      region    = x[1]
      is_remote = local.access_trusted_aa00-to-shared_aa00_prod.networks.remote == x[0]
    }
  }

  access_trusted_aa00-to-shared_aa00_prod-map = { for k, v in local._access_trusted_aa00-to-shared_aa00_prod-map : k => merge(v, {
    tunnels : { for idx in range(2) :
      format("%s-%02d", k, idx) => {
        name = format("vpn-%s-%s-%s-%02d-%s",
          random_id.access_trusted_aa00-to-shared_aa00_prod-seed.hex,
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
          ? local.access_trusted_aa00-to-shared_aa00_prod.networks.remote
          : local.access_trusted_aa00-to-shared_aa00_prod.networks.local
        ), v.region, idx)
        peer_asn = (
          v.is_local
          ? local._networks[local.access_trusted_aa00-to-shared_aa00_prod.networks.remote].asn
          : local._networks[local.access_trusted_aa00-to-shared_aa00_prod.networks.local].asn
        )
        self_name = v.name
        peer_name = (
          v.is_local
          ? format("vpn-%s-%s-%s-%s",
            random_id.access_trusted_aa00-to-shared_aa00_prod-seed.hex,
            local._networks[local.access_trusted_aa00-to-shared_aa00_prod.networks.remote].prefix,
            local._regions[v.region],
            random_id.id.hex
          )
          : format("vpn-%s-%s-%s-%s",
            random_id.access_trusted_aa00-to-shared_aa00_prod-seed.hex,
            local._networks[local.access_trusted_aa00-to-shared_aa00_prod.networks.local].prefix,
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

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering
resource "google_compute_network_peering" "access_trusted_aa00-to-shared_aa00_prod" {
  for_each = { for peering in local.access_trusted_aa00-to-shared_aa00_prod.peerings : format("%s-%s", peering.local, peering.remote) => peering }
  name = format("peer-%s-%s-%s",
    random_id.access_trusted_aa00-to-shared_aa00_prod-seed.hex,
    local._networks[each.value.local].prefix,
    random_id.id.hex
  )
  network              = format("projects/%s/global/networks/%s", var.project_id, format("%s-%s", local._networks[each.value.local].prefix, random_id.id.hex))
  peer_network         = format("projects/%s/global/networks/%s", var.project_id, format("%s-%s", local._networks[each.value.remote].prefix, random_id.id.hex))
  export_custom_routes = each.value.export_custom_routes
  import_custom_routes = each.value.import_custom_routes
}


# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_ha_vpn_gateway
resource "google_compute_ha_vpn_gateway" "access_trusted_aa00-to-shared_aa00_prod" {
  for_each = local.access_trusted_aa00-to-shared_aa00_prod-map

  provider = google-beta
  name     = each.value.name
  project  = var.project_id
  region   = each.value.region
  network  = each.value.network

  depends_on = [
    google_compute_network.shared_aa00_prod,
    google_compute_network.access_trusted_aa00,
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router
resource "google_compute_router" "access_trusted_aa00-to-shared_aa00_prod" {
  for_each = local.access_trusted_aa00-to-shared_aa00_prod-map

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
    google_compute_ha_vpn_gateway.access_trusted_aa00-to-shared_aa00_prod,
  ]
}

resource "google_compute_vpn_tunnel" "access_trusted_aa00-to-shared_aa00_prod" {
  for_each = merge(values(local.access_trusted_aa00-to-shared_aa00_prod-map).*.tunnels...)

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
    google_compute_ha_vpn_gateway.access_trusted_aa00-to-shared_aa00_prod,
    google_compute_router.access_trusted_aa00-to-shared_aa00_prod,
  ]
}

resource "google_compute_router_interface" "access_trusted_aa00-to-shared_aa00_prod" {
  for_each = merge(values(local.access_trusted_aa00-to-shared_aa00_prod-map).*.tunnels...)

  project = var.project_id

  region = each.value.region
  name   = each.value.name
  router = each.value.router
  ip_range = (
    each.value.is_local
    ? format("%s/%d", cidrhost(cidrsubnet("169.254.0.0/16", 14, random_integer.access_trusted_aa00-to-shared_aa00_prod[each.value.self_key].result), 1), 30)
    : format("%s/%d", cidrhost(cidrsubnet("169.254.0.0/16", 14, random_integer.access_trusted_aa00-to-shared_aa00_prod[each.value.peer_key].result), 2), 30)
  )

  vpn_tunnel = each.value.name

  depends_on = [
    google_compute_ha_vpn_gateway.access_trusted_aa00-to-shared_aa00_prod,
    google_compute_router.access_trusted_aa00-to-shared_aa00_prod,
    google_compute_vpn_tunnel.access_trusted_aa00-to-shared_aa00_prod,
  ]
}

resource "google_compute_router_peer" "access_trusted_aa00-to-shared_aa00_prod" {
  for_each = merge(values(local.access_trusted_aa00-to-shared_aa00_prod-map).*.tunnels...)

  project = var.project_id

  name     = each.value.name
  region   = each.value.region
  router   = each.value.router
  peer_asn = each.value.peer_asn
  peer_ip_address = (
    each.value.is_local
    ? cidrhost(cidrsubnet("169.254.0.0/16", 14, random_integer.access_trusted_aa00-to-shared_aa00_prod[each.value.self_key].result), 2)
    : cidrhost(cidrsubnet("169.254.0.0/16", 14, random_integer.access_trusted_aa00-to-shared_aa00_prod[each.value.peer_key].result), 1)
  )
  interface = each.value.name

  depends_on = [
    google_compute_ha_vpn_gateway.access_trusted_aa00-to-shared_aa00_prod,
    google_compute_router.access_trusted_aa00-to-shared_aa00_prod,
    google_compute_vpn_tunnel.access_trusted_aa00-to-shared_aa00_prod,
    google_compute_router_interface.access_trusted_aa00-to-shared_aa00_prod,
  ]
}

resource "google_network_connectivity_spoke" "access_trusted_aa00-to-shared_aa00_prod" {
  for_each = { for k, v in google_compute_ha_vpn_gateway.access_trusted_aa00-to-shared_aa00_prod : k => v if startswith(k, "access_trusted_aa00") }

  project = var.project_id

  name = each.value.name

  location = each.value.region

  hub = google_network_connectivity_hub.access_trusted_aa00.id

  linked_vpn_tunnels {
    site_to_site_data_transfer = true
    uris                       = [for k, v in google_compute_vpn_tunnel.access_trusted_aa00-to-shared_aa00_prod : v.self_link if v.region == each.value.region && endswith(v.vpn_gateway, each.value.name)]
  }

  depends_on = [
    google_compute_router.access_trusted_aa00,
    google_compute_vpn_tunnel.access_trusted_aa00-to-shared_aa00_prod
  ]
}


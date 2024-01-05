resource "random_id" "access_trusted-to-shared_aa00_nonprod-seed" {
  byte_length = 2
}

resource "random_integer" "access_trusted-to-shared_aa00_nonprod" {
  for_each = { for k, v in merge(values(local.access_trusted-to-shared_aa00_nonprod-map).*.tunnels...) : k => {} if v.is_local }
  min      = 0
  max      = 4095
  seed     = format("%s-%s", random_id.access_trusted-to-shared_aa00_nonprod-seed.hex, each.key)
}

resource "null_resource" "access_trusted-to-shared_aa00_nonprod" {
  depends_on = [
    google_compute_network.access_trusted_transit,
    google_compute_network.access_trusted_aa00,
    google_compute_network.shared_aa00_nonprod,
    google_network_connectivity_hub.access_trusted_aa00,
  ]
}

locals {
  access_trusted-to-shared_aa00_nonprod = {
    regions = ["us-east4", "us-west1"]
    networks = {
      local  = "access_trusted_transit",
      remote = "shared_aa00_nonprod",
    }
    tunnel_count = 1
    peerings = [
      {
        ## VPC Peering from access-trusted-transit to shared-vpc-nonprod
        local                = "access_trusted_aa00",
        remote               = "shared_aa00_nonprod",
        export_custom_routes = true,
        import_custom_routes = false,
      },
      {
        ## VPC Peering from shared-vpc-nonprod to access-trusted-transit
        local                = "shared_aa00_nonprod",
        remote               = "access_trusted_aa00",
        export_custom_routes = false,
        import_custom_routes = true,
      },
    ]
  }

  _access_trusted-to-shared_aa00_nonprod-map = {
    for x in setproduct(values(local.access_trusted-to-shared_aa00_nonprod.networks), local.access_trusted-to-shared_aa00_nonprod.regions) :
    join("-", [x[0], x[1]]) => {
      asn = try(
        local._networks[x[0]].regional_asn[x[1]],
        local._networks[x[0]].shared_asn,
        local._default_asn
      )
      key      = x[0]
      is_local = local.access_trusted-to-shared_aa00_nonprod.networks.local == x[0]
      name = format("vpn-%s-%s-%s-%s",
        random_id.access_trusted-to-shared_aa00_nonprod-seed.hex,
        local._networks[x[0]].prefix,
        local._regions[x[1]],
        random_id.id.hex
      )
      network   = format("%s-%s", local._networks[x[0]].prefix, random_id.id.hex)
      prefix    = local._networks[x[0]].prefix
      region    = x[1]
      is_remote = local.access_trusted-to-shared_aa00_nonprod.networks.remote == x[0]
    }
  }

  access_trusted-to-shared_aa00_nonprod-map = { for k, v in local._access_trusted-to-shared_aa00_nonprod-map : k => merge(v, {
    tunnels : { for idx in range(local.access_trusted-to-shared_aa00_nonprod.tunnel_count) :
      format("%s-%02d", k, idx) => {
        name = format("vpn-%s-%s-%s-%02d-%s",
          random_id.access_trusted-to-shared_aa00_nonprod-seed.hex,
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
          ? local.access_trusted-to-shared_aa00_nonprod.networks.remote
          : local.access_trusted-to-shared_aa00_nonprod.networks.local
        ), v.region, idx)
        peer_asn = (
          v.is_local
          ? try(
            local._networks[local.access_trusted-to-shared_aa00_nonprod.networks.remote].regional_asn[v.region],
            local._networks[local.access_trusted-to-shared_aa00_nonprod.networks.remote].shared_asn,
            local._default_asn
          )
          : try(
            local._networks[local.access_trusted-to-shared_aa00_nonprod.networks.local].regional_asn[v.region],
            local._networks[local.access_trusted-to-shared_aa00_nonprod.networks.local].shared_asn,
            local._default_asn
          )
        )
        self_name = v.name
        peer_name = (
          v.is_local
          ? format("vpn-%s-%s-%s-%s",
            random_id.access_trusted-to-shared_aa00_nonprod-seed.hex,
            local._networks[local.access_trusted-to-shared_aa00_nonprod.networks.remote].prefix,
            local._regions[v.region],
            random_id.id.hex
          )
          : format("vpn-%s-%s-%s-%s",
            random_id.access_trusted-to-shared_aa00_nonprod-seed.hex,
            local._networks[local.access_trusted-to-shared_aa00_nonprod.networks.local].prefix,
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

## Used to workaround multiple VPC Peering update issue
## => https://github.com/hashicorp/terraform-provider-google/issues/3034
resource "time_sleep" "access_trusted-to-shared_aa00_nonprod" {
  create_duration = "5s"
  depends_on = [
    null_resource.access_trusted-to-shared_aa00_nonprod,
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering
resource "google_compute_network_peering" "access_trusted-to-shared_aa00_nonprod" {
  for_each = { for peering in local.access_trusted-to-shared_aa00_nonprod.peerings : format("%s-%s", peering.local, peering.remote) => peering }
  name = format("peer-%s-%s-%s",
    random_id.access_trusted-to-shared_aa00_nonprod-seed.hex,
    local._networks[each.value.local].prefix,
    random_id.id.hex
  )
  network                             = format("projects/%s/global/networks/%s", var.project_id, format("%s-%s", local._networks[each.value.local].prefix, random_id.id.hex))
  peer_network                        = format("projects/%s/global/networks/%s", var.project_id, format("%s-%s", local._networks[each.value.remote].prefix, random_id.id.hex))
  export_custom_routes                = each.value.export_custom_routes
  import_custom_routes                = each.value.import_custom_routes
  export_subnet_routes_with_public_ip = false
  import_subnet_routes_with_public_ip = false


  depends_on = [
    null_resource.access_trusted-to-shared_aa00_nonprod,
    time_sleep.access_trusted-to-shared_aa00_nonprod,
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_ha_vpn_gateway
resource "google_compute_ha_vpn_gateway" "access_trusted-to-shared_aa00_nonprod" {
  for_each = local.access_trusted-to-shared_aa00_nonprod-map

  provider = google-beta
  name     = each.value.name
  project  = var.project_id
  region   = each.value.region
  network  = each.value.network

  depends_on = [
    null_resource.access_trusted-to-shared_aa00_nonprod,
    google_compute_network.access_trusted_aa00,
  ]
}

data "google_compute_ha_vpn_gateway" "gateway" {
  name    = google_compute_ha_vpn_gateway.access_trusted-to-shared_aa00_nonprod["shared_aa00_nonprod-us-east4"].name
  project = var.project_id
  region  = google_compute_ha_vpn_gateway.access_trusted-to-shared_aa00_nonprod["shared_aa00_nonprod-us-east4"].region
}
# google_compute_ha_vpn_gateway.access_trusted-to-shared_aa00_nonprod["core_wan-us-east4"]
# google_compute_ha_vpn_gateway.access_trusted-to-shared_aa00_nonprod["shared_aa00_nonprod-us-east4"]

output "gateway" {
  value = data.google_compute_ha_vpn_gateway.gateway
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router
resource "google_compute_router" "access_trusted-to-shared_aa00_nonprod" {
  for_each = local.access_trusted-to-shared_aa00_nonprod-map

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
    null_resource.access_trusted-to-shared_aa00_nonprod,
  ]
}

resource "google_compute_vpn_tunnel" "access_trusted-to-shared_aa00_nonprod" {
  for_each = merge(values(local.access_trusted-to-shared_aa00_nonprod-map).*.tunnels...)

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
    null_resource.access_trusted-to-shared_aa00_nonprod,
    google_compute_router.access_trusted-to-shared_aa00_nonprod,
    google_compute_ha_vpn_gateway.access_trusted-to-shared_aa00_nonprod,
  ]
}

resource "google_compute_router_interface" "access_trusted-to-shared_aa00_nonprod" {
  for_each = merge(values(local.access_trusted-to-shared_aa00_nonprod-map).*.tunnels...)

  project = var.project_id

  region = each.value.region
  name   = each.value.name
  router = each.value.router
  ip_range = (
    each.value.is_local
    ? format("%s/%d", cidrhost(cidrsubnet("169.254.0.0/16", 14, random_integer.access_trusted-to-shared_aa00_nonprod[each.value.self_key].result), 1), 30)
    : format("%s/%d", cidrhost(cidrsubnet("169.254.0.0/16", 14, random_integer.access_trusted-to-shared_aa00_nonprod[each.value.peer_key].result), 2), 30)
  )

  vpn_tunnel = each.value.name

  depends_on = [
    null_resource.access_trusted-to-shared_aa00_nonprod,
    google_compute_router.access_trusted-to-shared_aa00_nonprod,
    google_compute_vpn_tunnel.access_trusted-to-shared_aa00_nonprod,
  ]
}

resource "google_compute_router_peer" "access_trusted-to-shared_aa00_nonprod" {
  for_each = merge(values(local.access_trusted-to-shared_aa00_nonprod-map).*.tunnels...)

  project = var.project_id

  name                      = each.value.name
  region                    = each.value.region
  router                    = each.value.router
  peer_asn                  = each.value.peer_asn
  advertised_route_priority = 200
  peer_ip_address = (
    each.value.is_local
    ? cidrhost(cidrsubnet("169.254.0.0/16", 14, random_integer.access_trusted-to-shared_aa00_nonprod[each.value.self_key].result), 2)
    : cidrhost(cidrsubnet("169.254.0.0/16", 14, random_integer.access_trusted-to-shared_aa00_nonprod[each.value.peer_key].result), 1)
  )
  interface = each.value.name

  depends_on = [
    null_resource.access_trusted-to-shared_aa00_nonprod,
    google_compute_router.access_trusted-to-shared_aa00_nonprod,
    google_compute_router_interface.access_trusted-to-shared_aa00_nonprod,
  ]
}

# resource "google_network_connectivity_spoke" "access_trusted-to-shared_aa00_nonprod" {
#   for_each = { for k, v in google_compute_ha_vpn_gateway.access_trusted-to-shared_aa00_nonprod : k => v if(
#     startswith(k, "access_trusted_transit") &&
#     length(merge(values(local.access_trusted-to-shared_aa00_nonprod-map).*.tunnels...)) > 0
#   ) }

#   project = var.project_id

#   name = each.value.name

#   location = each.value.region

#   hub = google_network_connectivity_hub.access_trusted_transit.id

#   linked_vpn_tunnels {
#     site_to_site_data_transfer = true
#     uris = [
#       for k, v in google_compute_vpn_tunnel.access_trusted-to-shared_aa00_nonprod : v.self_link
#       if(
#         v.region == each.value.region &&
#         endswith(v.vpn_gateway, each.value.name)
#       )
#     ]
#   }

#   depends_on = [
#     null_resource.access_trusted-to-shared_aa00_nonprod,
#     google_compute_vpn_tunnel.access_trusted-to-shared_aa00_nonprod,
#   ]
# }


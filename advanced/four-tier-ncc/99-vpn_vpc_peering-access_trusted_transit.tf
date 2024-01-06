resource "null_resource" "access_trusted_aaXX" {
  depends_on = [
    google_compute_network.access_trusted_transit,
    google_compute_network.access_trusted_aa00,
    google_compute_network.shared_aa00_prod,
    google_network_connectivity_hub.access_trusted_aa00,
  ]
}

locals {
  access_trusted_aaXX_peerings = [
    {
      ## VPC Peering from access-trusted-transit to shared-vpc-nonprod
      hub   = "access_trusted_aa00",
      spoke = "shared_aa00_nonprod",
    },
    {
      ## VPC Peering from access-trusted-transit to shared-vpc-nonprod
      hub   = "access_trusted_aa00",
      spoke = "shared_aa00_prod",
    },
  ]
}

resource "random_id" "access_trusted_aaXX" {
  for_each    = toset(local.access_trusted_aaXX_peerings.*.spoke)
  byte_length = 2
}

## Used to workaround multiple VPC Peering update issue
## => https://github.com/hashicorp/terraform-provider-google/issues/3034
resource "time_sleep" "access_trusted_aaXX" {
  create_duration = "5s"
  depends_on = [
    null_resource.access_trusted_aaXX,
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering
resource "google_compute_network_peering" "access_trusted_aaXX" {
  for_each = merge([for v in local.access_trusted_aaXX_peerings : { for x in [values(v), reverse(values(v))] : join("-", [x[0], x[1]]) => {
    name = format("peer-%s-%s-%s",
      random_id.access_trusted_aaXX[(x[0] == v.spoke ? x[0] : x[1])].hex,
      local._networks[x[0]].prefix,
      random_id.id.hex
    )
    local                = x[0]
    remote               = x[1]
    export_custom_routes = x[0] == v.hub,
    import_custom_routes = x[0] == v.spoke,
  } }]...)

  name                                = each.value.name
  network                             = format("projects/%s/global/networks/%s", var.project_id, format("%s-%s", local._networks[each.value.local].prefix, random_id.id.hex))
  peer_network                        = format("projects/%s/global/networks/%s", var.project_id, format("%s-%s", local._networks[each.value.remote].prefix, random_id.id.hex))
  export_custom_routes                = each.value.export_custom_routes
  import_custom_routes                = each.value.import_custom_routes
  export_subnet_routes_with_public_ip = false
  import_subnet_routes_with_public_ip = false

  depends_on = [
    null_resource.access_trusted_aaXX,
    time_sleep.access_trusted_aaXX,
  ]
}


module "test_v1" {
  source     = "../../modules/ncc-ha-vpn"
  config_map = local._networks
  project_id = var.project_id
  ncc_hub    = google_network_connectivity_hub.access_trusted_transit.id
  input_list = [
    {
      regions = ["us-east4"]
      networks = {
        hub   = "access_trusted_transit",
        spoke = "shared_aa00_nonprod",
      }
      tunnel_count = 1
    },
    {
      regions = ["us-east4", "us-west1"]
      networks = {
        hub   = "access_trusted_transit",
        spoke = "shared_aa00_prod",
      }
      tunnel_count = 1
    }
  ]

  random_id = random_id.id

  depends_on = [
    null_resource.access_trusted_aaXX
  ]
}
# setproduct([local.alpha[1].networks.hub,local.alpha[1].networks.spoke],local.alpha[1].regions,)

# concat(setproduct([local.alpha[1].networks.hub,],[local.alpha[1].networks.spoke],local.alpha[1].regions,),setproduct([local.alpha[1].networks.spoke],[local.alpha[1].networks.hub],local.alpha[1].regions,) )

# setproduct([format("%s-%s",local.alpha[1].networks.hub,local.alpha[1].networks.spoke)], local.alpha[1].regions)
# setproduct([format("%s-%s",local.alpha[1].networks.hub,local.alpha[1].networks.spoke)], local.alpha[1].regions) 

# concat(flatten(setproduct([local.alpha[1].networks.hub,],[local.alpha[1].networks.spoke],local.alpha[1].regions,)),flatten(setproduct([local.alpha[1].networks.spoke],[local.alpha[1].networks.hub],local.alpha[1].regions,) ))

# locals {
#   alpha = [
#     {
#       regions = ["us-east4"]
#       networks = {
#         hub   = "access_trusted_transit",
#         spoke = "shared_aa00_nonprod",
#       }
#       tunnel_count = 1
#     },
#     {
#       regions = ["us-east4", "us-west1"]
#       networks = {
#         hub   = "access_trusted_transit",
#         spoke = "shared_aa00_prod",
#       }
#       tunnel_count = 2
#     }
#   ]
# }

#  merge(values( module.test_v1.foo).*.tunnels...)
# output "vpn_tunnels" {
#   value     = module.test_v1.vpn_tunnels
#   sensitive = true
# }


# values(module.test_v1.foo).*.asn
# distinct(values(module.test_v1.foo).*.name)

# merge(flatten(values({for k,v in module.test_v1.foo: k => {region= v.region, name =v.name}})))


# merge([for v in module.test_v1.foo :  { (v.name) = {region = v.region,network = v.network }}]...)

# merge([for k, v in module.test_v1.foo : { (v.name) = v.key }]...)

# {for k,v in module.test_v1.foo: k => {}
#  distinct_name_regions =
#   distinct({    for item in values(module.test_v1.foo) : item.name => item.region  })

#  distinct_name_region_list = 
#  distinct(
# merge(distinct([    for k, v in module.test_v1.foo : {(v.name) = v.region}  ]))
#     )

# # module.test_v1.foo["access_trusted_transit-us-east4"]

# # distinct([for vpn_gateway in values(module.test_v1.linked_vpn_tunnels).*.vpn_gateway: regex("projects/.*/regions/(?P<region>[^/]*)/*",vpn_gateway).region])
# # resource "google_network_connectivity_spoke" "access_trusted-to-shared_aa00_nonprod" {
# #   for_each = { for k, v in google_compute_ha_vpn_gateway.access_trusted-to-shared_aa00_nonprod : k => v if(
# #     startswith(k, "access_trusted_transit") &&
# #     length(merge(values(local.access_trusted-to-shared_aa00_nonprod-map).*.tunnels...)) > 0
# #   ) }

# #   project = var.project_id

# #   name = each.value.name

# #   location = each.value.region

# #   hub = google_network_connectivity_hub.access_trusted_transit.id

# #   linked_vpn_tunnels {
# #     site_to_site_data_transfer = true
# #     uris = [
# #       for k, v in google_compute_vpn_tunnel.access_trusted-to-shared_aa00_nonprod : v.self_link
# #       if(
# #         v.region == each.value.region &&
# #         endswith(v.vpn_gateway, each.value.name)
# #       )
# #     ]
# #   }

# #   depends_on = [
# #     null_resource.access_trusted-to-shared_aa00_nonprod,
# #     google_compute_vpn_tunnel.access_trusted-to-shared_aa00_nonprod,
# #   ]
# # }



# # output "linked_vpn_tunnels" {
# #   value = module.test_v1.linked_vpn_tunnels
# #   sensitive = true
# # }

# # values(module.test_v1.linked_vpn_tunnels).*.vpn_gateway

# # regexall(".*/projects/.*/regions/(?P<region>[^/]*)/*", values(module.test_v1.linked_vpn_tunnels).*.vpn_gateway).region

# #       region     = regex("projects/.*/regions/(?P<region>[^/]*)/*", subnetwork_self_link).region

# # regex("[a-z]+","Valentina")
# # formatlist(regex("[a-z]+",%s), ["Valentina", "Ander", "Olivia", "Sam"])
# # [
# #   "Hello, Valentina!",
# #   "Hello, Ander!",
# #   "Hello, Olivia!",
# #   "Hello, Sam!",
# # ]

# # locals {
# #   vpn_gateways = tolist(values(module.test_v1.linked_vpn_tunnels).*.vpn_gateway)
# #   regions = formatlist("%s", [for gateway in tolist(values(module.test_v1.linked_vpn_tunnels).*.vpn_gateway) : regex("projects/.*/regions/([^/]*)/.*", gateway)])
# # }

# # distinct([for vpn_gateway in values(module.test_v1.linked_vpn_tunnels).*.vpn_gateway: regex("projects/.*/regions/([^/]*)/.*", vpn_gateway).region])
# # distinct([for vpn_gateway in values(module.test_v1.linked_vpn_tunnels).*.vpn_gateway: regex("projects/.*/regions/(?P<region>[^/]*)/*",vpn_gateway).region])
# # output "regions" {
# #   value = local.regions
# # }



# # formatlist(regex("projects/.*/regions/(?P<region>[^/]*)/*", %s), values(module.test_v1.linked_vpn_tunnels).*.vpn_gateway)

# # [
# #   "Salutations, Valentina!",
# #   "Salutations, Ander!",
# #   "Salutations, Olivia!",
# #   "Salutations, Sam!",
# # ]


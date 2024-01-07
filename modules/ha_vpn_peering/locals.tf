
locals {
  random_id = var.random_id

  _list_map = merge([for map in var.input_list : {
    for x in concat(
      setproduct(
        [map.networks.hub],
        [map.networks.spoke],
        map.regions,
      ),
      setproduct(
        [map.networks.spoke],
        [map.networks.hub],
        map.regions,
      ),
      ) : join("-", [x[0], x[1], x[2]]) => {
      name = format("vpn-%s-%s-%s-%s",
        random_id.seed.hex,
        var.config_map[x[0]].prefix,
        module.utils.region_short_name_map[x[2]],
        local.random_id.hex
      )

      asn = try(
        var.config_map[x[0]].regional_asn[x[2]],
        var.config_map[x[0]].shared_asn,
        var.default_asn
      )

      key          = x[0]
      peer_key     = x[1]
      is_spoke     = map.networks.spoke == x[0]
      is_hub       = map.networks.hub == x[0]
      tunnel_count = map.tunnel_count
      network      = format("%s-%s", var.config_map[x[0]].prefix, local.random_id.hex)
      networks     = map.networks
      prefix       = var.config_map[x[0]].prefix
      region       = x[2]
    }
    }]
  ...)

  tunnel_map = merge(
    flatten([
      for k, v in local._list_map : {
        for idx in range(v.tunnel_count) : format("%s-%02d", k, idx) => format("%s-%s-%s-%02d", v.peer_key, v.key, v.region, idx)
      } if v.is_hub
      ]
    )
  ...)


  #   tunnel_list = flatten([for k, v in local._list_map : { for idx in range(v.tunnel_count) : format("%s-%02d", k, idx) => format("%s-%s-%s-%02d", v.peer_key, v.key, v.region, k, idx) if v.is_hub }])

  map = { for k, v in local._list_map : k => merge(v,
    {
      tunnels : { for idx in range(v.tunnel_count) :
        format("%s-%02d", k, idx) => {
          #   name = format("vpn-%s-%s-%s-%02d-%s",
          #     random_id.seed.hex,
          #     var.config_map[v.key].prefix,
          #     module.utils.region_short_name_map[v.region],
          #     idx,
          #     local.random_id.hex,
          #   )
          is_hub   = v.is_hub
          region   = v.region
          router   = v.name
          key      = v.key
          self_key = format("%s-%02d", k, idx)
          peer_key = format("%s-%s-%02d", (v.is_hub
            ? join("-", [v.networks.spoke, v.networks.hub])
            : join("-", [v.networks.hub, v.networks.spoke])
          ), v.region, idx)

          peer_asn = (
            v.is_hub
            ? try(
              var.config_map[v.networks.spoke].regional_asn[v.region],
              var.config_map[v.networks.spoke].shared_asn,
              var.default_asn
            )
            : try(
              var.config_map[v.networks.hub].regional_asn[v.region],
              var.config_map[v.networks.hub].shared_asn,
              var.default_asn
            )
          )
          self_name = v.name
          peer_name = (
            v.is_hub
            ? format("vpn-%s-%s-%s-%s",
              random_id.seed.hex,
              var.config_map[v.networks.spoke].prefix,
              module.utils.region_short_name_map[v.region],
              local.random_id.hex
            )
            : format("vpn-%s-%s-%s-%s",
              random_id.seed.hex,
              var.config_map[v.networks.hub].prefix,
              module.utils.region_short_name_map[v.region],
              local.random_id.hex
            )
          )
          vpn_gateway_interface = idx
          vpn_gateway           = v.name
        }
      }
    }

    )
  }

  distinct_map = merge([for v in local.map : { format("%s-%s", v.key, v.region) = {
    name    = v.name
    region  = v.region,
    network = v.network
    key     = v.key
    asn     = v.asn
    is_hub  = v.is_hub
  } }]...)
}
output "foo" {
  value = local.map
}

# output "map" {
#   value = {
#     config_map  = local.map
#     tunnel_bits = random_integer.tunnel_bits
#     # input      = var.input
#   }
# }



#   map = local._list_map
#   _map = {
#     for x in setproduct(values(var.input.networks), var.input.regions) :
#     join("-", [x[0], x[1]]) => {
#       asn = try(
#         var.config_map[x[0]].regional_asn[x[1]],
#         var.config_map[x[0]].shared_asn,
#         var.default_asn
#       )
#       key      = x[0]
#       is_spoke = var.input.networks.spoke == x[0]
#       is_hub   = var.input.networks.hub == x[0]

#       name = format("vpn-%s-%s-%s-%s",
#         random_id.seed.hex,
#         var.config_map[x[0]].prefix,
#         module.utils.region_short_name_map[x[1]],
#         local.random_id.hex
#       )
#       network = format("%s-%s", var.config_map[x[0]].prefix, local.random_id.hex)
#       prefix  = var.config_map[x[0]].prefix
#       region  = x[1]
#     }
#   }

#   map = { for k, v in local._map : k => merge(v, {
#     tunnels : { for idx in range(var.input.tunnel_count) :
#       format("%s-%02d", k, idx) => {
#         name = format("vpn-%s-%s-%s-%02d-%s",
#           random_id.seed.hex,
#           var.config_map[v.key].prefix,
#           module.utils.region_short_name_map[v.region],
#           idx,
#           local.random_id.hex,
#         )
#         is_hub   = v.is_hub
#         region   = v.region
#         router   = v.name
#         self_key = format("%s-%02d", k, idx)
#         peer_key = format("%s-%s-%02d", (
#           v.is_hub
#           ? var.input.networks.spoke
#           : var.input.networks.hub
#         ), v.region, idx)
#         peer_asn = (
#           v.is_hub
#           ? try(
#             var.config_map[var.input.networks.spoke].regional_asn[v.region],
#             var.config_map[var.input.networks.spoke].shared_asn,
#             var.default_asn
#           )
#           : try(
#             var.config_map[var.input.networks.hub].regional_asn[v.region],
#             var.config_map[var.input.networks.hub].shared_asn,
#             var.default_asn
#           )
#         )
#         self_name = v.name
#         peer_name = (
#           v.is_hub
#           ? format("vpn-%s-%s-%s-%s",
#             random_id.seed.hex,
#             var.config_map[var.input.networks.spoke].prefix,
#             module.utils.region_short_name_map[v.region],
#             local.random_id.hex
#           )
#           : format("vpn-%s-%s-%s-%s",
#             random_id.seed.hex,
#             var.config_map[var.input.networks.hub].prefix,
#             module.utils.region_short_name_map[v.region],
#             local.random_id.hex
#           )
#         )
#         vpn_gateway_interface = idx
#         vpn_gateway           = v.name
#       }
#     }
#     })
#   }

# {
#   tunnels : { for idx in range(var.input.tunnel_count) :
#     format("%s-%02d", k, idx) => {
#       name = format("vpn-%s-%s-%s-%02d-%s",
#         random_id.seed.hex,
#         var.config_map[v.key].prefix,
#         module.utils.region_short_name_map[v.region],
#         idx,
#         local.random_id.hex,
#       )
#       is_hub   = v.is_hub
#       region   = v.region
#       router   = v.name
#       self_key = format("%s-%02d", k, idx)
#       peer_key = format("%s-%s-%02d", (
#         v.is_hub
#         ? var.input.networks.spoke
#         : var.input.networks.hub
#       ), v.region, idx)
#       peer_asn = (
#         v.is_hub
#         ? try(
#           var.config_map[var.input.networks.spoke].regional_asn[v.region],
#           var.config_map[var.input.networks.spoke].shared_asn,
#           var.default_asn
#         )
#         : try(
#           var.config_map[var.input.networks.hub].regional_asn[v.region],
#           var.config_map[var.input.networks.hub].shared_asn,
#           var.default_asn
#         )
#       )
#       self_name = v.name
#       peer_name = (
#         v.is_hub
#         ? format("vpn-%s-%s-%s-%s",
#           random_id.seed.hex,
#           var.config_map[var.input.networks.spoke].prefix,
#           module.utils.region_short_name_map[v.region],
#           local.random_id.hex
#         )
#         : format("vpn-%s-%s-%s-%s",
#           random_id.seed.hex,
#           var.config_map[var.input.networks.hub].prefix,
#           module.utils.region_short_name_map[v.region],
#           local.random_id.hex
#         )
#       )
#       vpn_gateway_interface = idx
#       vpn_gateway           = v.name
#     }
#   }
# }

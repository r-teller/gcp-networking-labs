
locals {
  random_id = var.random_id
  _list_map = merge([for map in var.input_list : {
    for x in concat(
      setproduct(
        [map.spoke_config_map_tag],
        keys(map.regions),
      ),
      ) : join("-", [x[0], x[1]]) => {
      name = format("vpn-%s-%s-%s-%s",
        random_id.seed.hex,
        var.config_map[x[0]].prefix,
        module.utils.region_short_name_map[x[1]],
        local.random_id.hex
      )
      asn = try(
        var.config_map[x[0]].regional_asn[x[1]],
        var.config_map[x[0]].shared_asn,
        var.default_asn
      )

      key            = x[0]
      peer_addresses = map.regions[x[1]].peer_addresses
      length         = length(map.regions[x[1]].peer_addresses)
      peer_asn       = map.regions[x[1]].peer_asn
      tunnel_count   = map.regions[x[1]].tunnel_count

      network = format("%s-%s", var.config_map[x[0]].prefix, local.random_id.hex)
      # networks     = map.networks
      prefix = var.config_map[x[0]].prefix
      region = x[1]
    }
    }]
  ...)

  tunnel_map = merge(
    flatten([
      for k, v in local._list_map : {
        for idx in range(v.tunnel_count) : format("%s-%02d", k, idx) => format("%s-%s-%02d", v.key, v.region, idx)
      }
      ]
    )
  ...)


  map = { for k, v in local._list_map : k => merge(v,
    {
      tunnels : { for idx in range(v.tunnel_count) :
        format("%s-%02d", k, idx) => {
          region                = v.region
          router                = v.name
          key                   = v.key
          self_key              = format("%s-%02d", k, idx)
          parent_key            = k
          peer_asn              = v.peer_asn
          self_name             = v.name
          peer_address          = v.peer_addresses[idx]
          vpn_gateway_interface = idx
          vpn_gateway           = v.name
        }
      }
  }) }

  distinct_map = merge([for v in local.map : { format("%s-%s", v.key, v.region) = {
    name         = v.name
    region       = v.region,
    network      = v.network
    key          = v.key
    asn          = v.asn
    tunnel_count = v.tunnel_count
  } }]...)
}

locals {
  random_id = var.random_id
  _map = {
    for k1, v1 in var.input.regions : format("%s-redis-%s", var.input.name_prefix, k1) => {
      name = format("%s-redis-%s-%s",
        var.input.name_prefix,
        module.utils.region_short_name_map[k1],
        local.random_id.hex
      )
      ip_cidr_range = v1.ip_cidr_range
      region        = k1
    }
  }

  map   = local._map
  cache = ""
}
resource "random_id" "seed" {
  byte_length = 2
}

## Used to workaround multiple VPC Peering update issue
## => https://github.com/hashicorp/terraform-provider-google/issues/3034
resource "time_sleep" "time_sleep" {
  create_duration = "5s"
  # depends_on = [
  #   null_resource.access_trusted_aaXX,
  # ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering
resource "google_compute_network_peering" "hub-to-spoke" {
  # for_each = merge([for v in var.var.input_list : { for x in [values(v), reverse(values(v))] : join("-", [x[0], x[1]]) => {
  #   name = format("peer-%s-%s-%s",
  #     random_id.access_trusted_aaXX[(x[0] == v.spoke ? x[0] : x[1])].hex,
  #     var.var.config_map[x[0]].prefix,
  #     random_id.id.hex
  #   )
  #   local                = x[0]
  #   remote               = x[1]
  #   export_custom_routes = x[0] == v.hub,
  #   import_custom_routes = x[0] == v.spoke,
  # } }]...)
  for_each = { for v in var.input_list : format("%s-%s", v.hub, v.spoke) => v }
  name = format("peer-%s-%s-%s",
    random_id.seed.hex,
    var.config_map[each.value.hub].prefix,
    local.random_id.hex
  )
  network                             = format("projects/%s/global/networks/%s", var.project_id, format("%s-%s", var.config_map[each.value.hub].prefix, local.random_id.hex))
  peer_network                        = format("projects/%s/global/networks/%s", var.project_id, format("%s-%s", var.config_map[each.value.spoke].prefix, local.random_id.hex))
  export_custom_routes                = true
  import_custom_routes                = false
  export_subnet_routes_with_public_ip = false
  import_subnet_routes_with_public_ip = false

  depends_on = [
    # null_resource.access_trusted_aaXX,
    time_sleep.time_sleep,
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering
resource "google_compute_network_peering" "spoke-to-hub" {
  # for_each = merge([for v in var.var.input_list : { for x in [values(v), reverse(values(v))] : join("-", [x[0], x[1]]) => {
  #   name = format("peer-%s-%s-%s",
  #     random_id.access_trusted_aaXX[(x[0] == v.spoke ? x[0] : x[1])].hex,
  #     var.var.config_map[x[0]].prefix,
  #     random_id.id.hex
  #   )
  #   local                = x[0]
  #   remote               = x[1]
  #   export_custom_routes = x[0] == v.hub,
  #   import_custom_routes = x[0] == v.spoke,
  # } }]...)
  for_each = { for v in var.input_list : format("%s-%s", v.spoke, v.hub) => v }
  name = format("peer-%s-%s-%s",
    random_id.seed.hex,
    var.config_map[each.value.spoke].prefix,
    local.random_id.hex
  )
  network                             = format("projects/%s/global/networks/%s", var.project_id, format("%s-%s", var.config_map[each.value.spoke].prefix, local.random_id.hex))
  peer_network                        = format("projects/%s/global/networks/%s", var.project_id, format("%s-%s", var.config_map[each.value.hub].prefix, local.random_id.hex))
  export_custom_routes                = false
  import_custom_routes                = true
  export_subnet_routes_with_public_ip = false
  import_subnet_routes_with_public_ip = false

  depends_on = [
    # null_resource.access_trusted_aaXX,
    time_sleep.time_sleep,
  ]
}

resource "random_id" "seed" {
  for_each    = { for v in var.input_list : format("%s-%s", v.hub, v.spoke) => v }
  byte_length = 2
}

## Used to workaround multiple VPC Peering update issue
## => https://github.com/hashicorp/terraform-provider-google/issues/3034
resource "time_sleep" "time_sleep" {
  create_duration = "5s"
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering
resource "google_compute_network_peering" "hub-to-spoke" {
  for_each = { for v in var.input_list : format("%s-%s", v.hub, v.spoke) => v }
  name = format("peer-%s-%s-%s",
    random_id.seed[format("%s-%s", each.value.hub, each.value.spoke)].hex,
    var.config_map[each.value.hub].prefix,
    local.random_id.hex
  )
  network                             = format("projects/%s/global/networks/%s", var.project_id, format("%s-%s", var.config_map[each.value.hub].prefix, local.random_id.hex))
  peer_network                        = format("projects/%s/global/networks/%s", var.project_id, format("%s-%s", var.config_map[each.value.spoke].prefix, local.random_id.hex))
  export_custom_routes                = true
  import_custom_routes                = true
  export_subnet_routes_with_public_ip = false
  import_subnet_routes_with_public_ip = false

  depends_on = [
    time_sleep.time_sleep,
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering
resource "google_compute_network_peering" "spoke-to-hub" {
  for_each = { for v in var.input_list : format("%s-%s", v.spoke, v.hub) => v }
  name = format("peer-%s-%s-%s",
    random_id.seed[format("%s-%s", each.value.hub, each.value.spoke)].hex,
    var.config_map[each.value.spoke].prefix,
    local.random_id.hex
  )
  network                             = format("projects/%s/global/networks/%s", var.project_id, format("%s-%s", var.config_map[each.value.spoke].prefix, local.random_id.hex))
  peer_network                        = format("projects/%s/global/networks/%s", var.project_id, format("%s-%s", var.config_map[each.value.hub].prefix, local.random_id.hex))
  export_custom_routes                = true
  import_custom_routes                = true
  export_subnet_routes_with_public_ip = false
  import_subnet_routes_with_public_ip = false

  depends_on = [
    time_sleep.time_sleep,
  ]
}

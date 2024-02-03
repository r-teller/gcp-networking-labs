module "network-hub_shared_aa00" {
  source = "../../modules/network"

  project_id = var.project_id
  config_map = local._networks
  input = {
    config_map_tag = "hub_shared_aa00"
    routing_mode   = "GLOBAL"
    create_ncc_hub = true
    enable_private_googleapis = false
    enable_restriced_googleapis = false
  }
  random_id = random_id.id
}

module "network-spoke_nonprod_aa00" {
  source = "../../modules/network"

  project_id = var.project_id
  config_map = local._networks
  input = {
    config_map_tag = "spoke_nonprod_aa00"
    routing_mode   = "REGIONAL"
    create_ncc_hub = true
    enable_private_googleapis = false
    enable_restriced_googleapis = false
  }
  random_id = random_id.id
}

module "network-spoke_prod_aa00" {
  source = "../../modules/network"

  project_id = var.project_id
  config_map = local._networks
  input = {
    config_map_tag = "spoke_prod_aa00"
    routing_mode   = "REGIONAL"
    create_ncc_hub = true
    enable_private_googleapis = false
    enable_restriced_googleapis = false
  }
  random_id = random_id.id
}

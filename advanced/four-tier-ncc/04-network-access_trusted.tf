module "network-access_trusted_aa00" {
  source = "../../modules/network"

  project_id = var.project_id
  config_map = local._networks
  input = {
    config_map_tag = "access_trusted_aa00"
    routing_mode   = "REGIONAL"
    create_ncc_hub = true
  }
  random_id = random_id.id
}

module "network-access_trusted_ab00" {
  source = "../../modules/network"

  project_id = var.project_id
  config_map = local._networks
  input = {
    config_map_tag = "access_trusted_ab00"
    routing_mode   = "REGIONAL"
    create_ncc_hub = true
  }
  random_id = random_id.id
}


module "network-access_trusted_transit" {
  source = "../../modules/network"

  project_id = var.project_id
  config_map = local._networks
  input = {
    config_map_tag = "access_trusted_transit"
    routing_mode   = "REGIONAL"
    create_ncc_hub = true
  }
  random_id = random_id.id
}
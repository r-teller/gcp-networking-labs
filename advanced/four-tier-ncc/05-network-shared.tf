module "network-shared_aa00_prod" {
  source = "../../modules/network"

  project_id = var.project_id
  config_map = local._networks
  input = {
    config_map_tag = "shared_aa00_prod"
    routing_mode   = "REGIONAL"
    ncc_hub        = true
  }
  random_id = random_id.id
}

module "network-shared_aa00_nonprod" {
  source = "../../modules/network"

  project_id = var.project_id
  config_map = local._networks
  input = {
    config_map_tag = "shared_aa00_nonprod"
    routing_mode   = "REGIONAL"
    ncc_hub        = true
  }
  random_id = random_id.id
}
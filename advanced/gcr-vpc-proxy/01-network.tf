module "network-hub_shared_aa00" {
  source = "../../modules/network"

  project_id = var.project_id
  config_map = local._networks
  input = {
    config_map_tag = "hub_shared_aa00"
    routing_mode   = "REGIONAL"
  }
  random_id = random_id.id
}

module "network-on_prem_wan" {
  source = "../../modules/network"

  project_id = var.project_id
  config_map = local._networks
  input = {
    config_map_tag = "on_prem_wan"
    routing_mode   = "REGIONAL"
  }
  random_id = random_id.id
}

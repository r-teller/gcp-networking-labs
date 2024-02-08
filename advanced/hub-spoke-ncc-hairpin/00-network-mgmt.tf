module "network-mgmt" {
  source = "../../modules/network"

  project_id = var.project_id
  config_map = local._networks
  input = {
    config_map_tag = "mgmt"
    routing_mode   = "REGIONAL"
  }
  random_id = random_id.id
}

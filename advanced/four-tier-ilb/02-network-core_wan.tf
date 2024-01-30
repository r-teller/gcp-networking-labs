module "network-core_wan" {
  source = "../../modules/network"

  project_id = var.project_id
  config_map = local._networks
  input = {
    config_map_tag = "core_wan"
    routing_mode   = "GLOBAL"
    create_ncc_hub = true
  }
  random_id = random_id.id
}

module "network-distro_lan" {
  source = "../../modules/network"

  project_id = var.project_id
  config_map = local._networks
  input = {
    config_map_tag = "distro_lan"
    routing_mode   = "REGIONAL"
    create_ncc_hub = true
  }
  random_id = random_id.id
}

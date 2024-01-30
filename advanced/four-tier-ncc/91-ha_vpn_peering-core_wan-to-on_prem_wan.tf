resource "null_resource" "ha_vpn_peering-core_wan" {
  depends_on = [
    module.network-core_wan,
    module.network-on_prem_wan,
  ]
}

module "vpc_peering-core_wan" {
  source     = "../../modules/vpc_peering"
  
  count = 0 
  
  config_map = local._networks
  project_id = var.project_id
  random_id  = random_id.id
  input_list = []

  depends_on = [
    null_resource.ha_vpn_peering-core_wan
  ]
}

module "ha_vpn_peering-core_wan" {
  source     = "../../modules/ha_vpn_peering"

  count = 0 

  config_map = local._networks
  project_id = var.project_id
  input_list = [
    {
      regions = [
        "us-east4",
        "us-west1"
      ]
      use_ncc_hub = true
      networks = {
        hub   = "core_wan",
        spoke = "on_prem_wan",
      }
      tunnel_count = 1
    },
  ]

  random_id = random_id.id

  depends_on = [
    null_resource.ha_vpn_peering-core_wan
  ]
}

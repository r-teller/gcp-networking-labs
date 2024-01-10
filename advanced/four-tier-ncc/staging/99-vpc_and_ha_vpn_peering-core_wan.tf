resource "null_resource" "vpc_and_ha_vpn_peering-core_wan" {
  depends_on = [
    google_compute_network.core_wan,
    google_compute_network.on_prem_wan,
    google_network_connectivity_hub.core_wan,
  ]
}

module "ha_vpn_peering-core_wan" {
  source     = "../../modules/ha_vpn_peering"
  config_map = local._networks
  project_id = var.project_id
  ncc_hub    = google_network_connectivity_hub.core_wan
  input_list = [
    {
      regions = ["us-east4"]
      networks = {
        hub   = "core_wan",
        spoke = "on_prem_wan",
      }
      tunnel_count = 1
    },
  ]

  random_id = random_id.id

  depends_on = [
    null_resource.vpc_and_ha_vpn_peering-core_wan
  ]
}

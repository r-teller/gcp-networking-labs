resource "null_resource" "vpc_and_ha_vpn_peering-access_trusted" {
  depends_on = [
    module.network-access_trusted_aa00,
    module.network-access_trusted_ab00,
  ]
}

module "vpc_peering-access_trusted" {
  source     = "../../modules/vpc_peering"
  config_map = local._networks
  project_id = var.project_id
  random_id  = random_id.id
  input_list = [
    {
      ## VPC Peering from access-trusted-transit to shared-vpc-nonprod
      hub   = "access_trusted_aa00",
      spoke = "shared_aa00_nonprod",
    },
    {
      ## VPC Peering from access-trusted-transit to shared-vpc-nonprod
      hub   = "access_trusted_ab00",
      spoke = "shared_aa00_prod",
    }
  ]

  depends_on = [
    null_resource.vpc_and_ha_vpn_peering-access_trusted
  ]
}


module "ha_vpn_peering-access_trusted" {
  source     = "../../modules/ha_vpn_peering"
  config_map = local._networks
  project_id = var.project_id
  ncc_hub    = google_network_connectivity_hub.access_trusted_transit
  input_list = [
    {
      regions = ["us-east4"]
      networks = {
        hub   = "access_trusted_transit",
        spoke = "shared_aa00_nonprod",
      }
      tunnel_count = 1
    },
    {
      regions = ["us-east4", "us-west1"]
      networks = {
        hub   = "access_trusted_transit",
        spoke = "shared_aa00_prod",
      }
      tunnel_count = 1
    }
  ]

  random_id = random_id.id

  depends_on = [
    null_resource.vpc_and_ha_vpn_peering-access_trusted
  ]
}
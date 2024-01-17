resource "null_resource" "vpc_and_ha_vpn_peering-access_trusted" {
  depends_on = [
    module.network-access_trusted_transit,
    module.network-access_trusted_aa00,
    module.network-access_trusted_ab00,
    module.network-shared_aa00_nonprod,
    module.network-shared_ab00_nonprod,
    module.network-shared_aa00_prod,
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
      hub   = "access_trusted_aa00",
      spoke = "shared_aa00_prod",
    },
    {
      ## VPC Peering from access-trusted-transit to shared-vpc-nonprod
      hub   = "access_trusted_ab00",
      spoke = "shared_ab00_nonprod",
    },
  ]

  depends_on = [
    null_resource.vpc_and_ha_vpn_peering-access_trusted
  ]
}


module "ha_vpn_peering-access_trusted" {
  source     = "../../modules/ha_vpn_peering"
  config_map = local._networks
  project_id = var.project_id
  input_list = [
    {
      networks = {
        hub   = "access_trusted_transit",
        spoke = "shared_aa00_nonprod",
      }
      regions      = ["us-east4", "us-west1"]
      use_ncc_hub  = true
      tunnel_count = 1
    },
    {
      regions     = ["us-east4", "us-west1"]
      use_ncc_hub = true
      networks = {
        hub   = "access_trusted_transit",
        spoke = "shared_aa00_prod",
      }
      tunnel_count = 1
    },
    {
      networks = {
        hub   = "access_trusted_transit",
        spoke = "shared_ab00_nonprod",
      }
      regions      = ["us-east4"]
      use_ncc_hub  = true
      tunnel_count = 1
    },
  ]

  random_id = random_id.id

  depends_on = [
    null_resource.vpc_and_ha_vpn_peering-access_trusted
  ]
}

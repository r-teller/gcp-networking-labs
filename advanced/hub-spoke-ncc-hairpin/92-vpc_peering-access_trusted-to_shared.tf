resource "null_resource" "vpc_peering-hub_spoke" {
  depends_on = [
    module.network-hub_shared_aa00,
    module.network-spoke_prod_aa00,
    module.network-spoke_nonprod_aa00,
  ]
}

module "vpc_peering-hub_spoke" {
  source     = "../../modules/vpc_peering"
  config_map = local._networks
  project_id = var.project_id
  random_id  = random_id.id
  input_list = [
    {
      ## VPC Peering from access-trusted-transit to shared-vpc-nonprod
      hub   = "hub_shared_aa00",
      spoke = "spoke_prod_aa00",
    },
    {
      ## VPC Peering from access-trusted-transit to shared-vpc-nonprod
      hub   = "hub_shared_aa00",
      spoke = "spoke_nonprod_aa00",
    },
  ]

  depends_on = [
    null_resource.vpc_peering-hub_spoke
  ]
}

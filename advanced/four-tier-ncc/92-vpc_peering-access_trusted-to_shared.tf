resource "null_resource" "vpc_peering-access_trusted" {
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
  count = 1

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
    null_resource.vpc_peering-access_trusted
  ]
}

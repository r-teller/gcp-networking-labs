module "distro_lan-to-access_trusted" {
  count = 1
  # create_vms = true
  source = "../../modules/gce_vyos"

  depends_on = [
    module.network-distro_lan,
    module.network-access_trusted_transit,
    module.network-access_trusted_aa00,
    module.network-access_trusted_ab00,
  ]

  bucket_name = google_storage_bucket.bucket.name

  project_id = var.project_id
  config_map = local._networks
  random_id  = random_id.id
  input = {
    name_prefix     = "distro-lan-to-access-trusted"
    machine_type    = "n2d-standard-4"
    service_account = google_service_account.service_account.email

    regional_asn = {
      us-east4 : 4204100001,
      us-west1 : 4214100001,
      asia-southeast1 : 4224100001,
      europe-west3 : 4234100001,
    }
    zones = {
      "us-east4-a" = 1
      "us-west1-a" = 0
    }

    bootstrap = {
      enabled      = true
      bgp_enabled  = true
      output_gcs   = true
      output_local = true
    }
    network_tags = [
      format("%s-%s-default", local._networks["access_trusted_transit"]["prefix"], random_id.id.hex)
    ]
    interfaces = {
      0 = {
        config_map_tag = "distro_lan"
        subnetwork_tag = "network_appliance"
        use_ncc_hub    = true

      }
      1 = {
        config_map_tag   = "access_trusted_transit"
        subnetwork_tag   = "network_appliance"
        use_ncc_hub      = false
        external_enabled = true
      }
      2 = {
        config_map_tag = "access_trusted_aa00"
        subnetwork_tag = "network_appliance"
        use_ncc_hub    = true
      }
      3 = {
        config_map_tag = "access_trusted_ab00"
        subnetwork_tag = "network_appliance"
        use_ncc_hub    = true
      }
    }
  }
}

module "shared_aa00_prod_vyos" {
  count = 1
  # create_vms = true
  source = "../../modules/gce_vyos"

  depends_on = [
    module.network-shared_aa00_prod,
  ]

  bucket_name = google_storage_bucket.bucket.name

  project_id = var.project_id
  config_map = local._networks
  random_id  = random_id.id
  input = {
    name_prefix     = local._networks["shared_aa00_prod"].prefix
    machine_type    = "n2d-standard-2"
    service_account = google_service_account.service_account.email
    shared_asn      = 65255
    # regional_asn = {
    #   us-east4 : 4204100001,
    #   us-west1 : 4214100001,
    #   asia-southeast1 : 4224100001,
    #   europe-west3 : 4234100001,
    # }
    zones = {
      "us-east4-a" = 1
      "us-west1-a" = 0
    }

    bootstrap = {
      enabled      = true
      bgp_enabled  = true
      output_gcs   = true
      output_local = true
    }
    interfaces = {
      0 = {
        config_map_tag = "shared_aa00_prod"
        subnetwork_tag = "network_appliance"
        use_ncc_hub    = true
      }
    }
  }
}


# module "access_trusted_vpn" {
#   count = 1
#   # create_vms = true
#   source = "../../modules/gce_vyos"

#   depends_on = [
#     module.network-access_trusted_transit,
#   ]

#   bucket_name = google_storage_bucket.bucket.name

#   project_id = var.project_id
#   config_map = local._networks
#   random_id  = random_id.id
#   input = {
#     name_prefix     = "access-trusted-vpn"
#     machine_type    = "n2d-standard-2"
#     service_account = google_service_account.service_account.email

#     regional_asn = {
#       us-east4 : 4204100001,
#       us-west1 : 4214100001,
#       asia-southeast1 : 4224100001,
#       europe-west3 : 4234100001,
#     }
#     zones = {
#       "us-east4-a" = 1
#       "us-west1-a" = 0
#     }

#     bootstrap = {
#       enabled      = true
#       bgp_enabled  = false
#       output_gcs   = true
#       output_local = true
#     }
#     network_tags = [
#       format("%s-%s-default", local._networks["access_trusted_transit"]["prefix"], random_id.id.hex)
#     ]
#     interfaces = {
#       1 = {
#         config_map_tag   = "access_trusted_transit"
#         subnetwork_tag   = "network_appliance"
#         use_ncc_hub      = false
#         external_enabled = true
#       }
#     }
#   }
# }

module "distro_lan-to-access_trusted" {
  count  = 1
  source = "../../modules/gce_vyos"

  depends_on = [
    module.network-distro_lan,
    module.network-access_trusted_transit,
    module.network-access_trusted_aa00,
    module.network-access_trusted_ab00,
  ]

  project_id = var.project_id
  config_map = local._networks
  random_id  = random_id.id
  input = {
    name_prefix     = "distro-lan-to-access-trusted"
    machine_type    = "n2d-standard-4"
    service_account = google_service_account.vyos_compute_sa.email

    regional_asn = {
      us-east4 : 4204100001,
      us-west1 : 4214100001,
      asia-southeast1 : 4224100001,
      europe-west3 : 4234100001,
    }
    zones = {
      "us-east4-a" = 1
      "us-west1-a" = 1
    }

    interfaces = {
      0 = {
        config_map_tag = "distro_lan"
        subnetwork_tag = "network_appliance"
        ncc_hub_id     = module.network-distro_lan.ncc_hub.id

      }
      1 = {
        config_map_tag = "access_trusted_transit"
        subnetwork_tag = "network_appliance"
        # ncc_hub_id = module.network-access_trusted_transit.ncc_hub.id
      }
      2 = {
        config_map_tag = "access_trusted_aa00"
        subnetwork_tag = "network_appliance"
        # ncc_hub_id = module.network-access_trusted_aa00.ncc_hub.id
      }
      3 = {
        config_map_tag = "access_trusted_ab00"
        subnetwork_tag = "network_appliance"
        # ncc_hub_id = module.network-access_trusted_ab00.ncc_hub.id
      }
    }
  }
}

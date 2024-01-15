module "core_wan-to-distro_lan" {
  count  = 0
  source = "../../modules/gce_vyos"

  depends_on = [
    module.network-core_wan,
    module.network-distro_lan,
  ]

  project_id = var.project_id
  config_map = local._networks
  random_id  = random_id.id
  input = {
    name_prefix     = "core-wan-to-distro-lan"
    machine_type    = "n2d-standard-2"
    service_account = google_service_account.service_account.email

    regional_asn = {
      us-east4 : 4204100000,
      us-west1 : 4214100000,
      asia-southeast1 : 4224100000,
      europe-west3 : 4234100000,
    }

    zones = {
      "us-east4-a" = 1
      "us-west1-a" = 1
    }

    interfaces = {
      0 = {
        config_map_tag = "core_wan"
        subnetwork_tag = "network_appliance"
        use_ncc_hub    = true
      }
      1 = {
        config_map_tag = "distro_lan"
        subnetwork_tag = "network_appliance"
        use_ncc_hub    = true
      }
    }
  }
}

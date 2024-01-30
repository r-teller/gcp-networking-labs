module "distro_lan-to-access_trusted-redis" {
  count  = 0
  source = "../../modules/memorystore_redis"


  project_id = var.project_id
  config_map = local._networks
  random_id  = random_id.id

  input = {
    name_prefix = "distro-to-access"
    regions = {
      us-east4 : {
        ip_cidr_range = "192.168.255.128/28"
        size          = 1
        version       = "REDIS_7_0"
      }
      us-west1 : {
        ip_cidr_range = "192.168.255.144/28"
        size          = 1
        version       = "REDIS_7_0"
      }
    }
    config_map_tag = "mgmt"
  }
  depends_on = [
    module.network-mgmt,
  ]
}

module "distro_lan-to-access_trusted_a-palo" {
  count      = 1
  create_vms = true
  source     = "../../modules/gce_paloalto"

  depends_on = [
    module.network-mgmt,
    module.network-distro_lan,
    module.network-access_trusted_aa00,
    module.network-access_trusted_ab00,
  ]

  bucket_name = google_storage_bucket.bucket.name

  project_id = var.project_id
  config_map = local._networks
  random_id  = random_id.id
  input = {
    name_prefix     = "distro-to-access"
    machine_type    = "n2d-standard-8"
    service_account = google_service_account.service_account.email
    regional_asn = {
      us-east4 : 4204100001,
      us-west1 : 4214100001,
      asia-southeast1 : 4224100001,
      europe-west3 : 4234100001,
    }
    zones = {
      "us-east4-a" = 2
      "us-west1-a" = 2
    }

    regional_redis = try(module.distro_lan-to-access_trusted-redis[0].cache, null)

    # Can also be passed in this way
    # regional_redis = {
    #   us-east4 : module.distro_lan-to-access_trusted-redis[0].cache["us-east4"]
    # }
    bootstrap = {
      enabled      = true
      bgp_enabled  = true
      output_gcs   = true
      output_local = true
    }
    # bootstrap_enabled   = true
    # bootstrap_bgp       = true
    mgmt_interface_swap = true
    plugin_op_commands = {
      set-sess-ress = "True"
    }

    network_tags = [
      format("%s-%s-default", local._networks["mgmt"]["prefix"], random_id.id.hex)
    ]

    interfaces = {
      0 = {
        config_map_tag = "distro_lan"
        subnetwork_tag = "network_appliance"
        use_ncc_hub    = true

      }
      1 = {
        config_map_tag   = "mgmt"
        subnetwork_tag   = "mgmt"
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
      4 = {
        config_map_tag = "access_trusted_transit"
        subnetwork_tag = "network_appliance"
        use_ncc_hub    = true
      }
    }
  }
}

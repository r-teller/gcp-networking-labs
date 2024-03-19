module "gce_vyos-hub_shared_aa00" {
  count = 1
  # create_vms = true
  source = "../../modules/gce_vyos"

  depends_on = [
    module.network-hub_shared_aa00,
  ]

  bucket_name = google_storage_bucket.bucket.name

  project_id = var.project_id
  config_map = local._networks
  random_id  = random_id.id
  input = {
    name_prefix           = "hub-shared-aa00"
    machine_type          = "n2d-standard-2"
    service_account       = google_service_account.service_account.email
    enable_serial_console = true
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

    bootstrap = {
      enabled      = true
      bgp_enabled  = true
      output_gcs   = true
      output_local = true
    }
    network_tags = [
      format("%s-%s-default", local._networks["hub_shared_aa00"]["prefix"], random_id.id.hex)
    ]
    interfaces = {
      0 = {
        config_map_tag = "hub_shared_aa00"
        subnetwork_tag = "network_appliance"
        use_ncc_hub    = true
      }
    }
  }
}
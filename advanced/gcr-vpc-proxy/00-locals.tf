module "utils" {
  source = "terraform-google-modules/utils/google"
}

locals {
  continent_short_name = {
    asia         = "az"
    australia    = "au"
    europe       = "eu"
    northamerica = "na"
    southamerica = "sa"
    us           = "us"
    me           = "me"
  }
  _default_asn = 65534

  _networks = {
    hub_shared_aa00 = {
      prefix = "hub-shared-aa00"

      firewall_rules = {
        allow_iap = true
      }

      private_service_ranges = [
        {
          suffix        = "usc1",
          ip_cidr_range = "10.64.2.0/24",
        },
      ]
      subnetworks = [
        {
          region        = "us-central1",
          ip_cidr_range = "172.24.0.0/24",
        },
      ]
    }
  }
}

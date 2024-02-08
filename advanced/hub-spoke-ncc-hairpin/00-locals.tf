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
    mgmt : {
      prefix : "ha-mgmt",
      cloud_nat_all_subnets = true
      firewall_rules = {
        allowed_ssh_sources = ["0.0.0.0/0"]
      }
      private_service_ranges = [
        # {
        #   region        = "us-east4",
        #   ip_cidr_range = "192.168.128.0/28"
        # },
      ]
      subnetworks : [
        {
          region : "us-east4",
          ip_cidr_range : "192.168.255.0/27",
          tags = ["mgmt"],
        },
        {
          region : "us-west1",
          ip_cidr_range : "192.168.255.32/27",
          tags = ["mgmt"],
        }
      ]
    }
    hub_shared_aa00 = {
      prefix = "hub-shared-aa00"

      cloud_nat_all_subnets   = false
      advertise_local_subnets = true
      ## if regional ASN exists it will be preferred over the shared ASN
      shared_asn = 64516
      regional_asn = {
        us-east4 : 4202000002,
        us-west1 : 4212000002,
        asia-southeast1 : 4222000002,
        europe-west3 : 4232000002,
      }
      firewall_rules = {
        # allowed_ssh_sources = ["1.1.1.1"]
      }
      subnetworks = [
        {

          region = "us-east4",
          ip_cidr_range : "172.24.0.0/24",
          tags = ["network_appliance"],
          secondary_ip_ranges : [],
        },
        {
          region = "us-west1",
          ip_cidr_range : "172.24.1.0/24",
          tags = ["network_appliance"],
          secondary_ip_ranges : [],
        },
      ]
    }

    spoke_prod_aa00 = {
      prefix = "spoke-prod-aa00"
      ## if regional ASN exists it will be preferred over the shared ASN      
      regional_asn = {
        us-east4 : 4203000000,
        us-west1 : 4213000000,
        asia-southeast1 : 4223000000,
        europe-west3 : 4233000000,
      }
      cloud_nat_all_subnets = false
      subnetworks = [
        {
          region = "us-east4",
          ip_cidr_range : "10.0.96.0/27",
          tags = ["network_appliance"],
          secondary_ip_ranges : [],
        },
        {
          region = "us-west1",
          ip_cidr_range : "10.32.96.0/27",
          tags = ["network_appliance"],
          secondary_ip_ranges : [],
        }
      ]
    }

    spoke_nonprod_aa00 = {
      prefix = "spokae-nonprod-aa00"
      ## if regional ASN exists it will be preferred over the shared ASN
      regional_asn = {
        us-east4 : 4203000001,
        us-west1 : 4213000001,
        asia-southeast1 : 4223000001,
        europe-west3 : 4233000001,
      }
      cloud_nat_all_subnets = false
      subnetworks = [
        {
          region = "us-east4",
          ip_cidr_range : "10.0.0.0/27",
          tags = ["network_appliance"],
          secondary_ip_ranges : [],
        },
        {
          region = "us-west1",
          ip_cidr_range : "10.32.0.0/27",
          tags = ["network_appliance"],
          secondary_ip_ranges : [],
        }
      ]
    }
  }
}

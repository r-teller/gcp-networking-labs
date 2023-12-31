module "utils" {
  source = "terraform-google-modules/utils/google"
}

locals {
  _regions = {
    "us-east4" : module.utils.region_short_name_map["us-east4"]
    "us-west1" : module.utils.region_short_name_map["us-west1"]
    "us-central1" : module.utils.region_short_name_map["us-central1"]
    "asia-southeast1" : module.utils.region_short_name_map["asia-southeast1"]
    "europe-west3" : module.utils.region_short_name_map["europe-west3"]
  }

  continent_short_name = {
    asia         = "az"
    australia    = "au"
    europe       = "eu"
    northamerica = "na"
    southamerica = "sa"
    us           = "us"
    me           = "me"
  }
  # aggregated_advertisements = {
  #   "us-east4" : [],
  #   "us-west1" : [],
  #   "asia-southeast1" : [],
  #   "europe-west3" : [],
  # }
  _networks = {
    on_prem_wan = {
      prefix = "on-prem-wan"
      asn    = 64512

      subnetworks = [
        {
          region = "us-east4",
          ip_cidr_range : "192.168.0.0/24",
          tags = ["network_appliance"],
        },
        {
          region = "us-west1",
          ip_cidr_range : "192.168.64.0/24",
          tags = ["network_appliance"],
        },
        {
          region = "asia-southeast1",
          ip_cidr_range : "192.168.128.0/24",
          tags = ["network_appliance"],
        },
        {
          region = "europe-west3",
          ip_cidr_range : "192.168.192.0/24",
          tags = ["network_appliance"],
        },
      ]
    }

    core_wan = {
      asn    = 64513
      prefix = "core-wan"
      subnetworks = [
        {
          region = "us-east4",
          ip_cidr_range : "172.16.0.0/24",
          tags = ["network_appliance"],
        },
        {
          region = "us-west1",
          ip_cidr_range : "172.16.1.0/24",
          tags = ["network_appliance"],
        },
        {
          region = "asia-southeast1",
          ip_cidr_range : "172.16.2.0/24",
          tags = ["network_appliance"],
        },
        {
          region = "europe-west3",
          ip_cidr_range : "172.16.3.0/24",
          tags = ["network_appliance"],
        },
      ]
    }

    distro_lan = {
      prefix = "distro-lan"
      asn    = 64514
      summary_ip_ranges = {
        "us-east4" : [
          "10.0.0.0/11"
        ],
        "us-west1" : [
          "10.32.0.0/11"
        ],
        "asia-southeast1" : [
          "10.64.0.0/11"
        ],
        "europe-west3" : [
          "10.96.0.0/11"
        ],
      }
      subnetworks = [
        {
          region = "us-east4",
          ip_cidr_range : "172.17.0.0/24",
          tags = ["network_appliance"],
        },
        {
          region = "us-west1",
          ip_cidr_range : "172.17.1.0/24",
          tags = ["network_appliance"],
        },
        {
          region = "asia-southeast1",
          ip_cidr_range : "172.17.2.0/24",
          tags = ["network_appliance"],
        },
        {
          region = "europe-west3",
          ip_cidr_range : "172.17.3.0/24",
          tags = ["network_appliance"],
        },
      ]
    }

    access_trusted_transit = {
      prefix = "access-trusted-transit"
      asn    = 64514
      subnetworks = [
        {

          region = "us-east4",
          ip_cidr_range : "172.24.64.0/24",
          tags = ["network_appliance"],
        },
        {
          region = "us-west1",
          ip_cidr_range : "172.24.65.0/24",
          tags = ["network_appliance"],
        },
        {
          region = "asia-southeast1",
          ip_cidr_range : "172.24.66.0/24",
          tags = ["network_appliance"],
        },
        {
          region = "europe-west3",
          ip_cidr_range : "172.24.67.0/24",
          tags = ["network_appliance"],
        },
      ]
    }

    access_trusted_aa00 = {
      prefix = "access-trusted-aa00"
      asn    = 64515
      summary_ip_ranges = {
        "us-east4" : [
          "10.0.0.0/16"
        ],
        "us-west1" : [
          "10.32.0.0/16"
        ],
        "asia-southeast1" : [
          "10.64.0.0/16"
        ],
        "europe-west3" : [
          "10.96.0.0/16"
        ],
      }
      subnetworks = [
        {

          region = "us-east4",
          ip_cidr_range : "172.24.0.0/24",
          tags = ["network_appliance"],
        },
        {
          region = "us-west1",
          ip_cidr_range : "172.24.1.0/24",
          tags = ["network_appliance"],
        },
        {
          region = "asia-southeast1",
          ip_cidr_range : "172.24.2.0/24",
          tags = ["network_appliance"],
        },
        {
          region = "europe-west3",
          ip_cidr_range : "172.24.3.0/24",
          tags = ["network_appliance"],
        },
      ]
    }

    access_trusted_ab00 = {
      prefix = "access-trusted-ab00"
      asn    = 64516
      subnetworks = [
        {

          region = "us-east4",
          ip_cidr_range : "172.24.32.0/24",
          tags = ["network_appliance"],
        },
        {
          region = "us-west1",
          ip_cidr_range : "172.24.33.0/24",
          tags = ["network_appliance"],
        },
        {
          region = "asia-southeast1",
          ip_cidr_range : "172.24.34.0/24",
          tags = ["network_appliance"],
        },
        {
          region = "europe-west3",
          ip_cidr_range : "172.24.35.0/24",
          tags = ["network_appliance"],
        },
      ]
    }

    shared_aa00_prod = {
      prefix = "shared-aa00-prod"
      asn    = 4200000000
      summary_ip_ranges = {
        "us-east4" : ["10.0.96.0/22"]
      }
      subnetworks = [
        {
          region = "us-east4",
          ip_cidr_range : "10.0.96.0/27",
        }
      ]
    }
    shared_aa00_nonprod = {
      prefix = "shared-aa00-nonprod"
      asn    = 4200000000
      summary_ip_ranges = {
        "us-east4" : ["10.0.0.0/21"]
      }
      subnetworks = [
        {
          region = "us-east4",
          ip_cidr_range : "10.0.0.0/27",
        }
      ]
    }
  }
}

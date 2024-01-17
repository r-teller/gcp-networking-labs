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

    on_prem_wan = {
      prefix = "on-prem-wan"
      ## if regional ASN exists it will be preferred over the shared ASN
      shared_asn              = 16550
      regional_asn            = {}
      advertise_local_subnets = false
      summary_ip_ranges = {
        "us-east4" : [
          "10.0.0.0/8",
          "172.16.0.0/12",
          "192.168.0.0/16",
        ],
        "us-west1" : [
          "10.0.0.0/8",
          "172.16.0.0/12",
          "192.168.0.0/16",
        ],
        "asia-southeast1" : [
          "10.0.0.0/8",
          "172.16.0.0/12",
          "192.168.0.0/16",
        ],
        "europe-west3" : [
          "10.0.0.0/8",
          "172.16.0.0/12",
          "192.168.0.0/16",
        ],
      }
      cloud_nat_all_subnets = false
      subnetworks = [
        {
          region = "us-east4",
          ip_cidr_range : "192.168.0.0/24",
          tags = ["network_appliance", "cloud_nat"],
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
      shared_asn = 64513
      regional_asn = {
        us-east4 : 4200000000
        us-west1 : 4210000000
        asia-southeast1 : 4220000000
        europe-west3 : 4230000000
      }
      prefix                  = "core-wan"
      advertise_local_subnets = false
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
      ## if regional ASN exists it will be preferred over the shared ASN
      shared_asn = 64514
      regional_asn = {
        us-east4 : 4201000000,
        us-west1 : 4211000000,
        asia-southeast1 : 4221000000,
        europe-west3 : 4231000000,
      }
      advertise_local_subnets = false
      summary_ip_ranges = {
        "us-east4" : ["172.16.0.0/12"],
        "us-west1" : ["172.16.0.0/12"],
      }
      # summary_ip_ranges = {
      #   "us-east4" : [
      #     "10.0.0.0/11"
      #   ],
      #   "us-west1" : [
      #     "10.32.0.0/11"
      #   ],
      #   "asia-southeast1" : [
      #     "10.64.0.0/11"
      #   ],
      #   "europe-west3" : [
      #     "10.96.0.0/11"
      #   ],
      # }
      subnetworks = [
        {
          region = "us-east4",
          ip_cidr_range : "172.18.0.0/24",
          tags = ["network_appliance"],
        },
        {
          region = "us-west1",
          ip_cidr_range : "172.18.1.0/24",
          tags = ["network_appliance"],
        },
        {
          region = "asia-southeast1",
          ip_cidr_range : "172.18.2.0/24",
          tags = ["network_appliance"],
        },
        {
          region = "europe-west3",
          ip_cidr_range : "172.18.3.0/24",
          tags = ["network_appliance"],
        },
      ]
    }

    access_trusted_transit = {
      prefix = "access-trusted-transit"
      ## if regional ASN exists it will be preferred over the shared ASN
      shared_asn = 64515
      regional_asn = {
        us-east4 : 4202000001,
        us-west1 : 4212000001,
        asia-southeast1 : 4222000001,
        europe-west3 : 4232000001,
      }
      advertise_local_subnets = false
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
      
      cloud_nat_all_subnets = true
      ## if regional ASN exists it will be preferred over the shared ASN
      shared_asn = 64516
      regional_asn = {
        us-east4 : 4202000002,
        us-west1 : 4212000002,
        asia-southeast1 : 4222000002,
        europe-west3 : 4232000002,
      }
      advertise_local_subnets = true
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

      cloud_nat_all_subnets = true
      ## if regional ASN exists it will be preferred over the shared ASN
      shared_asn = 64517
      regional_asn = {
        us-east4 : 4202000003,
        us-west1 : 4212000003,
        asia-southeast1 : 4222000003,
        europe-west3 : 4232000003,
      }
      advertise_local_subnets = true
      summary_ip_ranges = {
        "us-east4" : [
          "10.1.0.0/16"
        ],
        "us-west1" : [
          "10.33.0.0/16"
        ],
        "asia-southeast1" : [
          "10.65.0.0/16"
        ],
        "europe-west3" : [
          "10.97.0.0/16"
        ],
      }
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
      ## if regional ASN exists it will be preferred over the shared ASN      
      regional_asn = {
        us-east4 : 4203000000,
        us-west1 : 4213000000,
        asia-southeast1 : 4223000000,
        europe-west3 : 4233000000,
      }
      advertise_local_subnets = false
      summary_ip_ranges = {
        "us-east4" : ["10.0.96.0/22"]
        "us-west1" : ["10.32.96.0/22"]
      }
      private_service_ranges = [
        {
          region        = "us-east4",
          ip_cidr_range = "10.0.99.0/24"
        },
      ]
      subnetworks = [
        {
          region = "us-east4",
          ip_cidr_range : "10.0.96.0/27",
          secondary_ip_ranges : [
            "100.64.96.0/22",
            "10.0.96.32/27",
          ],
        },
        {
          region = "us-west1",
          ip_cidr_range : "10.32.96.0/27",
        }
      ]
    }

    shared_aa00_nonprod = {
      prefix = "shared-aa00-nonprod"
      ## if regional ASN exists it will be preferred over the shared ASN
      regional_asn = {
        us-east4 : 4203000001,
        us-west1 : 4213000001,
        asia-southeast1 : 4223000001,
        europe-west3 : 4233000001,
      }
      advertise_local_subnets = false
      summary_ip_ranges = {
        "us-east4" : ["10.0.0.0/21"],
        "us-west1" : ["10.32.0.0/21"],
      }
      private_service_ranges = [
        {
          region        = "us-east4",
          ip_cidr_range = "10.0.3.0/24"
        },
        {
          region        = "us-west1",
          ip_cidr_range = "10.32.3.0/24"
        }
      ]
      subnetworks = [
        {
          region = "us-east4",
          ip_cidr_range : "10.0.0.0/27",
          secondary_ip_ranges : [
            "100.64.0.0/21",
            "10.0.0.64/27",
          ],
        },
        {
          region = "us-west1",
          ip_cidr_range : "10.32.0.0/27",
        }
      ]
    }


    shared_ab00_nonprod = {
      prefix = "shared-ab00-nonprod"
      ## if regional ASN exists it will be preferred over the shared ASN
      regional_asn = {
        us-east4 : 4203000011,
        us-west1 : 4213000011,
        asia-southeast1 : 4223000011,
        europe-west3 : 4233000011,
      }
      advertise_local_subnets = false
      summary_ip_ranges = {
        "us-east4" : ["10.1.0.0/21"],
        "us-west1" : ["10.33.0.0/21"],
      }
      private_service_ranges = [
        {
          region        = "us-east4",
          ip_cidr_range = "10.1.3.0/24"
        },
        {
          region        = "us-west1",
          ip_cidr_range = "10.33.3.0/24"
        }
      ]
      subnetworks = [
        {
          region = "us-east4",
          ip_cidr_range : "10.1.0.0/27",
        },
        {
          region = "us-west1",
          ip_cidr_range : "10.33.0.0/27",
        }
      ]
    }
  }
}

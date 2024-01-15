variable "default_asn" {
  type    = number
  default = 65534
}

variable "bucket_name" {
  type    = string
  default = null
}

variable "project_id" {
  type = string
}

variable "create_vms" {
  type    = bool
  default = true
}


variable "config_map" {
  description = "Map of network configurations"

  type = map(
    object({
      prefix                  = string
      shared_asn              = optional(number)
      regional_asn            = optional(map(number))
      advertise_local_subnets = optional(bool, false)
      cloud_nat_all_subnets   = optional(bool, false)
      summary_ip_ranges       = optional(map(list(string)))
      subnetworks = optional(list(object({
        region              = string
        ip_cidr_range       = string
        tags                = optional(list(string), [])
        secondary_ip_ranges = optional(list(string), [])
      })))
      private_service_ranges = optional(list(object({
        region        = string
        ip_cidr_range = string
      })))
  }))
}

variable "random_id" {
  default = null
}


variable "image" {
  // Hourly Licenses
  default = "https://www.googleapis.com/compute/v1/projects/paloaltonetworksgcp-public/global/images/vmseries-flex-bundle1-1110"
  # default = "https://www.googleapis.com/compute/v1/projects/paloaltonetworksgcp-public/global/images/vmseries-bundle2-1110"

  // BYOL License  
  # default = "https://www.googleapis.com/compute/v1/projects/paloaltonetworksgcp-public/global/images/vmseries-byol-1110"
}

variable "input" {
  type = object({
    name_prefix  = string
    shared_asn   = optional(number, null)
    regional_asn = optional(map(number))
    machine_type = optional(string, "n2-standard-8")
    bootstrap = optional(object({
      enabled      = optional(bool, false)
      bgp_enabled  = optional(bool, false)
      output_local = optional(bool, false)
      output_gcs   = optional(bool, false)
    }))
    regional_redis      = optional(any, null)
    mgmt_interface_swap = optional(bool, true)
    plugin_op_commands  = optional(map(string), null)
    zones               = map(number)
    network_tags        = optional(list(string), [])
    ssh_keys            = optional(string, null)
    service_account     = string
    interfaces = map(object({
      config_map_tag   = string
      subnetwork_tag   = optional(string, null)
      external_enabled = optional(bool, false)
      use_ncc_hub      = optional(bool, false)
    }))
  })
}


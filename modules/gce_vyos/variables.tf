variable "bucket_name" {
  type    = string
  default = null
}
variable "default_asn" {
  type    = number
  default = 65534
}

variable "project_id" {
  type = string
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
  type    = string
  default = "projects/rteller-demo-host-aaaa/global/images/vyos-advanced-v1-3-5"
}

variable "input" {
  type = object({
    name_prefix  = string
    shared_asn   = optional(number, null)
    regional_asn = optional(map(number))
    machine_type = optional(string, "n2-standard-4")
    bootstrap = optional(object({
      enabled      = optional(bool, false)
      bgp_enabled  = optional(bool, false)
      output_local = optional(bool, false)
      output_gcs   = optional(bool, false)
    }))
    zones           = map(number)
    network_tags        = optional(list(string), [])
    service_account = string
    interfaces = map(object({
      config_map_tag   = string
      subnetwork_tag   = optional(string, null)
      external_enabled = optional(bool, false)
      use_ncc_hub      = optional(bool, false)
    }))
  })
}


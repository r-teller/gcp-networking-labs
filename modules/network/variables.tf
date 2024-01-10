
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

variable "input" {
  type = object({
    routing_mode   = string,
    config_map_tag = string,
    ncc_hub        = optional(bool, false),
  })
}


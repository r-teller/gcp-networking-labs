variable "project_id" {
  type = string
}

variable "default_asn" {
  type    = number
  default = 65534
}

variable "config_map" {
  description = "Map of network configurations"

  type = map(object({
    prefix                  = string
    shared_asn              = optional(number)
    regional_asn            = optional(map(number))
    advertise_local_subnets = optional(bool, false)
    summary_ip_ranges       = optional(map(list(string)))
    subnetworks = list(object({
      region              = string
      ip_cidr_range       = string
      tags                = optional(list(string))
      secondary_ip_ranges = optional(list(string))
    }))
    private_service_ranges = optional(list(object({
      region        = string
      ip_cidr_range = string
    })))
  }))
}

variable "random_id" {
  default = null
}

variable "input_list" {
  type = list(
    object({
      regions = map(object({
        peer_addresses = list(string),
        peer_asn       = number,
        tunnel_count   = number,
      })),
      spoke_config_map_tag = string,
  }))
}

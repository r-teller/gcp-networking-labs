
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
      firewall_rules = optional(object({
        allow_all           = optional(bool, false)
        allow_rfc1918       = optional(bool, true)
        allow_rfc6598       = optional(bool, true)
        allow_iap           = optional(bool, true)
        allow_gfe           = optional(bool, true)
        allowed_ssh_sources = optional(list(string), [])
      }), {})
      summary_ip_ranges = optional(map(list(string)))
      subnetworks = optional(list(object({
        region              = string
        ip_cidr_range       = string
        tags                = optional(list(string), [])
        secondary_ip_ranges = optional(list(string), [])
      })), [])
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
    routing_mode                = string,
    enable_private_googleapis   = optional(bool, true),  ## <-- only one of these should be enabled, either private or restricted
    enable_restriced_googleapis = optional(bool, false), ## <-- only one of these should be enabled, either private or restricted
    config_map_tag              = string,
    create_ncc_hub              = optional(bool, false),
  })
}


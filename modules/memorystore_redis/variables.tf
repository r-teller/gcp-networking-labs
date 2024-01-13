variable "project_id" {
  type = string
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

variable "input" {
  type = object({
    name_prefix = string
    regions = map(object({
      ip_cidr_range = string
      replica_count = optional(number, 1)
      size          = optional(number, 5)
      version       = optiona(string, "redis_7_0")
    }))
    config_map_tag = string,
  })
}


output "cache" {
  value = local.cache
}

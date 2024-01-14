# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/redis_instance
resource "google_redis_instance" "cache" {
  for_each = var.input.regions

  project = var.project_id

  name = format("%s-redis-%s-%s",
    var.input.name_prefix,
    module.utils.region_short_name_map[each.key],
    local.random_id.hex
  )

  tier           = "STANDARD_HA"
  memory_size_gb = each.value.size
  replica_count  = 1
  # replica_count = 1
  read_replicas_mode = "READ_REPLICAS_DISABLED" #each.value.replica_count > 0 ? "READ_REPLICAS_ENABLED" : "READ_REPLICAS_DISABLED"
  region             = each.key

  auth_enabled = true

  transit_encryption_mode = "SERVER_AUTHENTICATION"

  authorized_network = format("projects/%s/global/networks/%s", var.project_id, format("%s-%s", var.config_map[var.input.config_map_tag].prefix, local.random_id.hex))
  reserved_ip_range  = each.value.ip_cidr_range

  redis_version = each.value.version
  display_name  = "Terraform Test Instance"
}

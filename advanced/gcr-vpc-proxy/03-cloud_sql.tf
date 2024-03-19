# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance
resource "google_sql_database_instance" "gsql_postgres" {
  for_each = toset(var.regions)

  project = var.project_id
  name    = format("gsql-demo-%s-%s", module.gcp_utils.region_short_name_map[lower(each.key)], random_id.id.hex)

  database_version = "POSTGRES_15"
  region           = each.key

  settings {
    # Second-generation instance tiers are based on the machine
    # type. See argument reference below.
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled    = false
      private_network = module.network-hub_shared_aa00.network.self_link
      allocated_ip_range = one(
        [for k, v in module.network-hub_shared_aa00.private_service_ranges : v.name if strcontains(v.name, module.gcp_utils.region_short_name_map[lower(each.key)])]
      )
      ssl_mode = "ALLOW_UNENCRYPTED_AND_ENCRYPTED"
    }
    deletion_protection_enabled = false
    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }

    availability_type = "ZONAL"
  }
  depends_on = [module.network-hub_shared_aa00]
}

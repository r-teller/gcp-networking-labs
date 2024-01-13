resource "google_redis_instance" "cache" {
  name           = "private-cache"
  tier           = "STANDARD_HA"
  memory_size_gb = 1

  location_id             = "us-central1-a"
  alternative_location_id = "us-central1-f"

  authorized_network = google_compute_network.redis-network.id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"

  redis_version = "REDIS_4_0"
  display_name  = "Terraform Test Instance"

  depends_on = [
    google_service_networking_connection.private_service_connection
  ]

  lifecycle {
    prevent_destroy = true
  }
}

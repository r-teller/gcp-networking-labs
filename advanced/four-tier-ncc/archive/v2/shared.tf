# resource "random_id" "secret" {
#   byte_length = 8
# }

# resource "random_id" "id" {
#   byte_length = 2
# }



# resource "google_service_account" "vyos_compute_sa" {
#   project      = var.project_id
#   account_id   = format("gce-vyos-appliance-sa-%s", random_id.id.hex)
#   display_name = "Service Account mounted on gce-vyos-network-appliance-sa compute instances"
# }

# resource "google_storage_bucket_iam_member" "instance_sa_bucket_permissions" {
#   for_each = toset([
#     "roles/storage.objectAdmin",
#     "roles/storage.legacyBucketReader",
#   ])
#   bucket = google_storage_bucket.bucket.name
#   role   = each.value
#   member = "serviceAccount:${google_service_account.vyos_compute_sa.email}"
#   depends_on = [
#     google_service_account.vyos_compute_sa
#   ]
# }

# resource "google_project_iam_member" "sa_log_writer" {
#   project    = var.project_id
#   member     = "serviceAccount:${google_service_account.vyos_compute_sa.email}"
#   role       = "roles/logging.logWriter"
#   depends_on = [google_service_account.vyos_compute_sa]
# }

# resource "google_project_iam_member" "sa_metric_writer" {
#   project    = var.project_id
#   member     = "serviceAccount:${google_service_account.vyos_compute_sa.email}"
#   role       = "roles/monitoring.metricWriter"
#   depends_on = [google_service_account.vyos_compute_sa]
# }


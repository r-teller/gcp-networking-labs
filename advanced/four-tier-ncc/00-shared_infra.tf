##################################
# Random Items                   #
##################################
resource "random_id" "secret" {
  byte_length = 8
}

resource "random_id" "id" {
  byte_length = 2
}

##################################
# Service Accounts               #
##################################
resource "google_service_account" "service_account" {
  project = var.project_id

  account_id   = format("gce-appliance-sa-%s", random_id.id.hex)
  display_name = "Service Account mounted on gce-network-appliance-sa compute instances"
}



##################################
# Storage Bucket CONFIGURATION   #
##################################
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket
resource "google_storage_bucket" "bucket" {
  project = var.project_id

  name          = format("%s-%s", "advanced-network-conf", random_id.id.hex)
  location      = "us-central1"
  force_destroy = true
}

##################################
# IAM Permissions                #
##################################
resource "google_storage_bucket_iam_member" "instance_sa_bucket_permissions" {
  for_each = toset([
    "roles/storage.objectAdmin",
    "roles/storage.legacyBucketReader",
  ])
  bucket = google_storage_bucket.bucket.name
  role   = each.value
  member = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_member" "sa_log_writer" {
  project = var.project_id
  member  = "serviceAccount:${google_service_account.service_account.email}"
  role    = "roles/logging.logWriter"

}

resource "google_project_iam_member" "sa_metric_writer" {
  project = var.project_id
  member  = "serviceAccount:${google_service_account.service_account.email}"
  role    = "roles/monitoring.metricWriter"
}
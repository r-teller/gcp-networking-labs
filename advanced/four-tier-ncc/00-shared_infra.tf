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

  name          = format("%s-%s", "advanced-network-vyos-conf", random_id.id.hex)
  location      = "us-central1"
  force_destroy = true
}

resource "google_storage_notification" "core_wan_to_distro_lan_vyos_usc1" {
  bucket         = google_storage_bucket.bucket.name
  payload_format = "JSON_API_V1"
  topic          = google_pubsub_topic.configuration_update_topic.id
  event_types    = ["OBJECT_FINALIZE", "OBJECT_METADATA_UPDATE"]
  depends_on     = [google_pubsub_topic_iam_member.pubsub_notification_event]
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


# ##################################
# # TOPIC CONFIGURATION            #
# ##################################
# data "google_storage_project_service_account" "gcs_account" {
#   project = var.project_id
# }


# resource "google_pubsub_topic" "configuration_update_topic" {
#   project = var.project_id
#   name    = format("%s-%s", "advanced-network-vyos-conf", random_id.id.hex)
# }

# resource "google_pubsub_topic_iam_member" "pubsub_notification_event" {
#   project = var.project_id
#   topic   = google_pubsub_topic.configuration_update_topic.id
#   role    = "roles/pubsub.publisher"
#   member  = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
# }

# ##################################
# # SUBSCRIPTION CONFIGURATION     #
# ##################################

# data "google_iam_policy" "subscription_subscriber" {
#   binding {
#     role = "roles/pubsub.subscriber"
#     members = [
#       "serviceAccount:${google_service_account.vyos_compute_sa.email}"
#     ]
#   }
# }

##################################
# NCC HUB CONFIGURATION          #
##################################





# resource "google_network_connectivity_hub" "access_trusted_0001" {
#   project = var.project_id

#   name = format("%s-%s", local._networks.access_trusted_0001.prefix, random_id.id.hex)
# }

# resource "google_network_connectivity_hub" "access_trusted_0002" {
#   project = var.project_id

#   name = format("%s-%s", local._networks.access_trusted_0002.prefix, random_id.id.hex)
# }



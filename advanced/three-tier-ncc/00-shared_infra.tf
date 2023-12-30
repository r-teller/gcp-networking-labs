##################################
# Cloud DNS Private Google APIS  #
##################################


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

##################################
# TOPIC CONFIGURATION            #
##################################
data "google_storage_project_service_account" "gcs_account" {
  project = var.project_id
}


resource "google_pubsub_topic" "configuration_update_topic" {
  project = var.project_id
  # name    = "vyos.${var.instance_name}.configuration"
  name = format("%s-%s", "advanced-network-vyos-conf", random_id.id.hex)
}

resource "google_pubsub_topic_iam_member" "pubsub_notification_event" {
  project = var.project_id
  topic   = google_pubsub_topic.configuration_update_topic.id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}

##################################
# SUBSCRIPTION CONFIGURATION     #
##################################

data "google_iam_policy" "subscription_subscriber" {
  binding {
    role = "roles/pubsub.subscriber"
    members = [
      "serviceAccount:${google_service_account.vyos_compute_sa.email}"
    ]
  }
}

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



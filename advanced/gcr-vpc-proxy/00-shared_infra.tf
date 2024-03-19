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

  account_id   = format("gcr-chisel-sa-%s", random_id.id.hex)
  display_name = "Service Account used by Chisel container to proxy traffic into the VPC"
}
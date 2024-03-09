resource "random_id" "id" {
  byte_length = 4
}

locals {
  name = "ihaz-cloud"
  domain = "echo.ihaz.cloud"
}

data "google_project" "project" {
  project_id = var.project_id
}


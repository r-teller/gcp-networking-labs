resource "google_project_service" "enabled_apis" {
  project = var.project_id
  for_each = toset([
    "certificatemanager.googleapis.com",
    "compute.googleapis.com",
    "networksecurity.googleapis.com",
    "run.googleapis.com",
  ])

  service = each.value

  disable_dependent_services = false
}

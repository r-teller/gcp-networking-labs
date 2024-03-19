# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service
resource "google_cloud_run_v2_service" "gcr_chisel" {
  for_each = toset(var.regions)

  project      = var.project_id
  name         = format("gcr-chisel-%s-%s", module.gcp_utils.region_short_name_map[lower(each.key)], random_id.id.hex)
  location     = each.key
  launch_stage = "BETA"

  template {
    scaling {
      min_instance_count = 1
      max_instance_count = 4
    }
    session_affinity = true
    containers {
      image = "jpillora/chisel:latest"
      ports {
        container_port = 80
      }
      resources {
        limits = {
          cpu    = "1000m"
          memory = "512Mi"
        }
        cpu_idle = false
      }
      args = [
        "server",
        "--port=80",
        "--socks5",
        "--keepalive=5m",
        "-v",
      ]
    }

    vpc_access {
      egress = "ALL_TRAFFIC"
      network_interfaces {
        network    = module.network-hub_shared_aa00.network.name
        subnetwork = one([for subnetwork in module.network-hub_shared_aa00.subnetworks : subnetwork.name if subnetwork.region == each.key])
      }
    }

    max_instance_request_concurrency = 10
  }

  depends_on = [module.network-hub_shared_aa00]
}

# ## https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_network_endpoint_group
# resource "google_compute_region_network_endpoint_group" "gcr_echo_neg" {
#   for_each = google_cloud_run_v2_service.gcr_echo

#   project = each.value.project

#   name                  = format("gcr-echo-neg-%s-%s", module.gcp_utils.region_short_name_map[lower(each.key)], random_id.id.hex)
#   network_endpoint_type = "SERVERLESS"
#   region                = each.key
#   cloud_run {
#     service = each.value.name
#   }
# }

# data "google_iam_policy" "gcr_echo_noauth" {
#   binding {
#     role = "roles/run.invoker"
#     members = [
#       "allUsers",
#     ]
#   }
# }

# resource "google_cloud_run_service_iam_policy" "gcr_echo_noauth" {
#   for_each = google_cloud_run_v2_service.gcr_echo

#   location = each.value.location
#   project  = each.value.project
#   service  = each.value.name

#   policy_data = data.google_iam_policy.gcr_echo_noauth.policy_data
# }

# # backend service with custom request and response headers
# resource "google_compute_backend_service" "gcr_echo_backend" {
#   project = var.project_id

#   name = format("l7-xlb-echo-bs-%s", random_id.id.hex)

#   load_balancing_scheme = "EXTERNAL_MANAGED"
#   protocol              = "HTTPS"
#   enable_cdn            = false

#   custom_request_headers = [
#     "mtls-Client-Geo-Location: {client_region_subdivision}, {client_city}",
#     "mtls-Client-Certificate-Present: {client_cert_present}",
#     "mtls-Client-Certificate-Valid: {client_cert_chain_verified}",
#     "mtls-Client-Certificate-Issuer: {client_cert_issuer_dn}",
#     "mtls-Client-Certificate-Subject: {client_cert_subject_dn}",
#   ]


#   dynamic "backend" {
#     for_each = google_compute_region_network_endpoint_group.gcr_echo_neg
#     content {
#       group = backend.value.id
#     }
#   }
# }


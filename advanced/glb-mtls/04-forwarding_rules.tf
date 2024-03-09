resource "google_compute_global_address" "default" {
  project = var.project_id

  provider = google-beta
  name     = format("l7-xlb-static-ip-%s", random_id.id.hex)
}

resource "google_compute_url_map" "gcr_echo_url_map" {
  project = var.project_id

  name            = format("l7-xlb-echo-url-map-%s", random_id.id.hex)
  default_service = google_compute_backend_service.gcr_echo_backend.id
}


resource "google_compute_target_https_proxy" "gcr_echo_https" {
  project = var.project_id

  name              = format("l7-xlb-echo-target-https-proxy-%s", random_id.id.hex)
  quic_override     = "DISABLE"
  url_map           = google_compute_url_map.gcr_echo_url_map.id
  ssl_certificates  = [google_compute_ssl_certificate.server_certificate.id]
  server_tls_policy = google_network_security_server_tls_policy.mtls_server_policy.id


}


resource "google_compute_global_forwarding_rule" "gcr_echo_xlb_forwarding_443" {
  project = var.project_id

  name                  = format("l7-xlb-echo-forwarding-rule-https-%s", random_id.id.hex)
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.gcr_echo_https.id
  ip_address            = google_compute_global_address.default.id


}


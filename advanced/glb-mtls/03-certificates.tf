# Create a private key for the root CA
resource "tls_private_key" "root_ca_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create a self-signed certificate for the root CA
resource "tls_self_signed_cert" "root_ca_cert" {
  private_key_pem = tls_private_key.root_ca_key.private_key_pem

  subject {
    common_name  = "Root CA"
    organization = "Ihaz Cloud"
  }

  is_ca_certificate     = true
  validity_period_hours = 87600 # 10 years
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
  ]
}


resource "tls_private_key" "server_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}


# Create a certificate signing request (CSR) for the server
resource "tls_cert_request" "server_csr" {
  private_key_pem = tls_private_key.server_key.private_key_pem

  subject {
    common_name  = local.domain
    organization = "Ihaz Cloud"
  }

  dns_names = ["${local.domain}", "*.${local.domain}"]
}

# Create a signed server certificate using the root CA
resource "tls_locally_signed_cert" "server_cert" {
  cert_request_pem   = tls_cert_request.server_csr.cert_request_pem
  ca_private_key_pem = tls_private_key.root_ca_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.root_ca_cert.cert_pem

  validity_period_hours = 8760 # 1 year
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "google_compute_ssl_certificate" "server_certificate" {
  project = var.project_id

  name        = format("server-cert-%s", random_id.id.hex)
  private_key = tls_private_key.server_key.private_key_pem
  certificate = tls_locally_signed_cert.server_cert.cert_pem
}

# Create a private key for the client
resource "tls_private_key" "client_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create a certificate signing request (CSR) for the client
resource "tls_cert_request" "client_csr" {
  private_key_pem = tls_private_key.client_key.private_key_pem

  subject {
    common_name  = "client.${local.domain}"
    organization = "Ihaz Cloud"
  }
}

# Create a signed client certificate using the root CA
resource "tls_locally_signed_cert" "client_cert" {
  cert_request_pem = tls_cert_request.client_csr.cert_request_pem

  ca_private_key_pem = tls_private_key.root_ca_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.root_ca_cert.cert_pem

  validity_period_hours = 8760 # 1 year
  allowed_uses = [
    "client_auth",
    "digital_signature",
    "key_encipherment",
  ]
}


# Store the client certificate in a local file
resource "local_file" "client_cert_file" {
  content  = tls_locally_signed_cert.client_cert.cert_pem
  filename = "${path.module}/secrets/client_cert.pem"
}

# Store the client private key in a local file
resource "local_file" "client_key_file" {
  content  = tls_private_key.client_key.private_key_pem
  filename = "${path.module}/secrets/client_key.pem"
}

# https://registry.terraform.io/providers/hashicorp/google/5.19.0/docs/resources/certificate_manager_trust_config
resource "google_certificate_manager_trust_config" "mtls_trust_config" {
  name        = format("mtls-trust-%s", random_id.id.hex)
  project     = var.project_id
  description = "mTLS Trust Config"
  location    = "global"

  trust_stores {
    trust_anchors {
      pem_certificate = tls_self_signed_cert.root_ca_cert.cert_pem
    }
  }

}

# https://registry.terraform.io/providers/hashicorp/google/5.19.0/docs/resources/network_security_server_tls_policy
resource "google_network_security_server_tls_policy" "mtls_server_policy" {
  project     = var.project_id
  provider    = google-beta
  name        = format("server-mtls-%s", random_id.id.hex)
  location    = "global"
  description = "TLS Policy for mTLS"
  allow_open  = "false"

  mtls_policy {
    client_validation_trust_config = google_certificate_manager_trust_config.mtls_trust_config.id
    client_validation_mode         = "ALLOW_INVALID_OR_MISSING_CLIENT_CERT"
  }

  lifecycle {
    ignore_changes = [
      mtls_policy[0].client_validation_trust_config,
    ]
  }
}

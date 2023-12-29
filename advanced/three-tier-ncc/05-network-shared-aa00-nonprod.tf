resource "google_compute_network" "shared_aa00_nonprod" {
  project                         = var.project_id
  name                            = format("%s-%s", local._networks.shared_aa00_nonprod.prefix, random_id.id.hex)
  delete_default_routes_on_create = true
  auto_create_subnetworks         = false

  routing_mode = "REGIONAL"
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_response_policy
resource "google_dns_response_policy" "shared_aa00_nonprod" {
  project = var.project_id

  response_policy_name = format("%s-%s", local._networks.shared_aa00_nonprod.prefix, random_id.id.hex)

  networks {
    network_url = google_compute_network.shared_aa00_nonprod.id
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_response_policy_rule
resource "google_dns_response_policy_rule" "shared_aa00_nonprod-a" {
  project = var.project_id

  response_policy = google_dns_response_policy.shared_aa00_nonprod.response_policy_name
  rule_name       = "private-googleapis-com"
  dns_name        = "private.googleapis.com."

  local_data {
    local_datas {
      name = "private.googleapis.com."
      type = "A"
      ttl  = 300
      rrdatas = [
        "199.36.153.8",
        "199.36.153.9",
        "199.36.153.10",
        "199.36.153.11"
      ]
    }
  }
}

resource "google_dns_response_policy_rule" "shared_aa00_nonprod-cname" {
  project = var.project_id

  response_policy = google_dns_response_policy.shared_aa00_nonprod.response_policy_name
  rule_name       = "star-googleapis-com"
  dns_name        = "*.googleapis.com."

  local_data {
    local_datas {
      name    = "*.googleapis.com."
      type    = "CNAME"
      ttl     = 300
      rrdatas = ["private.googleapis.com."]
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall
resource "google_compute_firewall" "shared_aa00_nonprod-allow_all" {
  project = var.project_id

  name    = format("%s-%s-allow-all", local._networks.shared_aa00_nonprod.prefix, random_id.id.hex)
  network = google_compute_network.shared_aa00_nonprod.self_link

  source_ranges      = ["0.0.0.0/0"]
  destination_ranges = []
  allow {
    protocol = "all"
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_route
resource "google_compute_route" "shared_aa00_nonprod-iap" {
  project = var.project_id

  name             = format("%s-%s-iap", local._networks.shared_aa00_nonprod.prefix, random_id.id.hex)
  network          = google_compute_network.shared_aa00_nonprod.self_link
  dest_range       = "35.235.240.0/20"
  next_hop_gateway = "https://www.googleapis.com/compute/v1/projects/rteller-demo-host-aaaa/global/gateways/default-internet-gateway"
}

resource "google_compute_route" "shared_aa00_nonprod-private" {
  project = var.project_id

  name             = format("%s-%s-private", local._networks.shared_aa00_nonprod.prefix, random_id.id.hex)
  network          = google_compute_network.shared_aa00_nonprod.self_link
  dest_range       = "199.36.153.8/30"
  next_hop_gateway = "https://www.googleapis.com/compute/v1/projects/rteller-demo-host-aaaa/global/gateways/default-internet-gateway"
}

resource "google_compute_route" "shared_aa00_nonprod-default" {
  project = var.project_id

  name             = format("%s-%s-default", local._networks.shared_aa00_nonprod.prefix, random_id.id.hex)
  network          = google_compute_network.shared_aa00_nonprod.self_link
  tags             = [format("%s-%s-default", local._networks.shared_aa00_nonprod.prefix, random_id.id.hex)]
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "https://www.googleapis.com/compute/v1/projects/rteller-demo-host-aaaa/global/gateways/default-internet-gateway"
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
resource "google_compute_subnetwork" "shared_aa00_nonprod" {
  for_each = { for x in local._networks.shared_aa00_nonprod.subnetworks : x.ip_cidr_range => x }

  project = var.project_id

  name    = format("%s-%s-%s", local._networks.shared_aa00_nonprod.prefix, replace(each.value.ip_cidr_range, "//|\\./", "-"), random_id.id.hex)
  network = google_compute_network.shared_aa00_nonprod.self_link

  private_ip_google_access = true
  ip_cidr_range            = each.value.ip_cidr_range
  region                   = each.value.region
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router
resource "google_compute_router" "shared_aa00_nonprod" {
  for_each = toset(distinct(local._networks.shared_aa00_nonprod.subnetworks.*.region))

  project = var.project_id

  name    = format("%s-%s", local._networks.shared_aa00_nonprod.prefix, random_id.id.hex)
  network = google_compute_network.shared_aa00_nonprod.self_link

  region = each.key
  bgp {
    asn               = local._networks.shared_aa00_nonprod.asn
    advertise_mode    = "CUSTOM"
    advertised_groups = []

    dynamic "advertised_ip_ranges" {
      for_each = local._networks.shared_aa00_nonprod.summary_ip_ranges[each.key]
      content {
        range = advertised_ip_ranges.value
      }
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat
resource "google_compute_router_nat" "shared_aa00_nonprod" {
  for_each = toset(distinct(local._networks.shared_aa00_nonprod.subnetworks.*.region))

  project = var.project_id

  name   = format("%s-%s", local._networks.shared_aa00_nonprod.prefix, random_id.id.hex)
  router = google_compute_router.shared_aa00_nonprod[each.key].name
  region = google_compute_router.shared_aa00_nonprod[each.key].region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  depends_on = [
    google_compute_router.shared_aa00_nonprod
  ]
}

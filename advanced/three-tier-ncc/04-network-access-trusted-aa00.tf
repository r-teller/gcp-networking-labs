resource "google_compute_network" "access_trusted_aa00" {
  project                         = var.project_id
  name                            = format("%s-%s", local._networks.access_trusted_aa00.prefix, random_id.id.hex)
  delete_default_routes_on_create = true
  auto_create_subnetworks         = false

  routing_mode = "REGIONAL"
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_response_policy
resource "google_dns_response_policy" "access_trusted_aa00" {
  project = var.project_id

  response_policy_name = format("%s-%s", local._networks.access_trusted_aa00.prefix, random_id.id.hex)

  networks {
    network_url = google_compute_network.access_trusted_aa00.id
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_response_policy_rule
resource "google_dns_response_policy_rule" "access_trusted_aa00-a" {
  project = var.project_id

  response_policy = google_dns_response_policy.access_trusted_aa00.response_policy_name
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

resource "google_dns_response_policy_rule" "access_trusted_aa00-cname" {
  project = var.project_id

  response_policy = google_dns_response_policy.access_trusted_aa00.response_policy_name
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
resource "google_compute_firewall" "access_trusted_aa00-allow_all" {
  project = var.project_id

  name    = format("%s-%s-allow-all", local._networks.access_trusted_aa00.prefix, random_id.id.hex)
  network = google_compute_network.access_trusted_aa00.self_link

  source_ranges      = ["0.0.0.0/0"]
  destination_ranges = []
  allow {
    protocol = "all"
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_route
resource "google_compute_route" "access_trusted_aa00-iap" {
  project = var.project_id

  name             = format("%s-%s-iap", local._networks.access_trusted_aa00.prefix, random_id.id.hex)
  network          = google_compute_network.access_trusted_aa00.self_link
  dest_range       = "35.235.240.0/20"
  next_hop_gateway = "https://www.googleapis.com/compute/v1/projects/rteller-demo-host-aaaa/global/gateways/default-internet-gateway"
}

resource "google_compute_route" "access_trusted_aa00-private" {
  project = var.project_id

  name             = format("%s-%s-private", local._networks.access_trusted_aa00.prefix, random_id.id.hex)
  network          = google_compute_network.access_trusted_aa00.self_link
  dest_range       = "199.36.153.8/30"
  next_hop_gateway = "https://www.googleapis.com/compute/v1/projects/rteller-demo-host-aaaa/global/gateways/default-internet-gateway"
}

resource "google_compute_route" "access_trusted_aa00-default" {
  project = var.project_id

  name             = format("%s-%s-default", local._networks.access_trusted_aa00.prefix, random_id.id.hex)
  network          = google_compute_network.access_trusted_aa00.self_link
  tags             = [format("%s-%s-default", local._networks.access_trusted_aa00.prefix, random_id.id.hex)]
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "https://www.googleapis.com/compute/v1/projects/rteller-demo-host-aaaa/global/gateways/default-internet-gateway"
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
resource "google_compute_subnetwork" "access_trusted_aa00" {
  for_each = { for x in local._networks.access_trusted_aa00.subnetworks : x.ip_cidr_range => x }

  project = var.project_id

  name    = format("%s-%s-%s", local._networks.access_trusted_aa00.prefix, replace(each.value.ip_cidr_range, "//|\\./", "-"), random_id.id.hex)
  network = google_compute_network.access_trusted_aa00.self_link

  private_ip_google_access = true
  ip_cidr_range            = each.value.ip_cidr_range
  region                   = each.value.region
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router
resource "google_compute_router" "access_trusted_aa00" {
  for_each = toset(distinct(local._networks.access_trusted_aa00.subnetworks.*.region))

  project = var.project_id

  name    = format("%s-%s", local._networks.access_trusted_aa00.prefix, random_id.id.hex)
  network = google_compute_network.access_trusted_aa00.self_link

  region = each.key
  bgp {
    asn               = local._networks.access_trusted_aa00.asn
    advertise_mode    = "CUSTOM"
    advertised_groups = []

    dynamic "advertised_ip_ranges" {
      for_each = local._networks.access_trusted_aa00.summary_ip_ranges[each.key]
      content {
        range = advertised_ip_ranges.value
      }
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat
resource "google_compute_router_nat" "access_trusted_aa00" {
  for_each = toset(distinct(local._networks.access_trusted_aa00.subnetworks.*.region))

  project = var.project_id

  name   = format("%s-%s", local._networks.access_trusted_aa00.prefix, random_id.id.hex)
  router = google_compute_router.access_trusted_aa00[each.key].name
  region = google_compute_router.access_trusted_aa00[each.key].region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  depends_on = [
    google_compute_router.access_trusted_aa00
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_interface
resource "google_compute_router_interface" "access_trusted_aa00_appliance_nic0" {
  for_each = { for x in local._networks.access_trusted_aa00.subnetworks : x.ip_cidr_range => x if contains(try(x.tags, []), "network_appliance") }

  project = var.project_id

  name               = format("%s-%s-%s", local._networks.access_trusted_aa00.prefix, format("nic%02d", 0), random_id.id.hex)
  router             = google_compute_router.access_trusted_aa00[each.value.region].name
  region             = each.value.region
  private_ip_address = cidrhost(google_compute_subnetwork.access_trusted_aa00[each.key].ip_cidr_range, -3)
  subnetwork         = google_compute_subnetwork.access_trusted_aa00[each.key].self_link
}

resource "google_compute_router_interface" "access_trusted_aa00_appliance_nic1" {
  for_each = { for x in local._networks.access_trusted_aa00.subnetworks : x.ip_cidr_range => x if contains(try(x.tags, []), "network_appliance") }

  project = var.project_id

  name                = format("%s-%s-%s", local._networks.access_trusted_aa00.prefix, format("nic%02d", 1), random_id.id.hex)
  router              = google_compute_router.access_trusted_aa00[each.value.region].name
  region              = each.value.region
  redundant_interface = google_compute_router_interface.access_trusted_aa00_appliance_nic0[each.key].name
  private_ip_address  = cidrhost(google_compute_subnetwork.access_trusted_aa00[each.key].ip_cidr_range, -4)
  subnetwork          = google_compute_subnetwork.access_trusted_aa00[each.key].self_link
}

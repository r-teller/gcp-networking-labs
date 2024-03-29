resource "google_compute_network" "access_trusted_transit" {
  project                         = var.project_id
  name                            = format("%s-%s", local._networks.access_trusted_transit.prefix, random_id.id.hex)
  delete_default_routes_on_create = true
  auto_create_subnetworks         = false

  routing_mode = "REGIONAL"
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/network_connectivity_hub
resource "google_network_connectivity_hub" "access_trusted_transit" {
  project = var.project_id

  name = format("%s-%s", local._networks.access_trusted_transit.prefix, random_id.id.hex)
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_response_policy
resource "google_dns_response_policy" "access_trusted_transit" {
  project = var.project_id

  response_policy_name = format("%s-%s", local._networks.access_trusted_transit.prefix, random_id.id.hex)

  networks {
    network_url = google_compute_network.access_trusted_transit.id
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_response_policy_rule
resource "google_dns_response_policy_rule" "access_trusted_transit-a" {
  project = var.project_id

  response_policy = google_dns_response_policy.access_trusted_transit.response_policy_name
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

resource "google_dns_response_policy_rule" "access_trusted_transit-cname" {
  project = var.project_id

  response_policy = google_dns_response_policy.access_trusted_transit.response_policy_name
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
resource "google_compute_firewall" "access_trusted_transit-allow_all" {
  project = var.project_id

  name    = format("%s-%s-allow-all", local._networks.access_trusted_transit.prefix, random_id.id.hex)
  network = google_compute_network.access_trusted_transit.self_link

  source_ranges      = ["0.0.0.0/0"]
  destination_ranges = []
  allow {
    protocol = "all"
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_route
resource "google_compute_route" "access_trusted_transit-iap" {
  project = var.project_id

  name             = format("%s-%s-iap", local._networks.access_trusted_transit.prefix, random_id.id.hex)
  network          = google_compute_network.access_trusted_transit.self_link
  dest_range       = "35.235.240.0/20"
  next_hop_gateway = "default-internet-gateway"
}

resource "google_compute_route" "access_trusted_transit-private" {
  project = var.project_id

  name             = format("%s-%s-private", local._networks.access_trusted_transit.prefix, random_id.id.hex)
  network          = google_compute_network.access_trusted_transit.self_link
  dest_range       = "199.36.153.8/30"
  next_hop_gateway = "default-internet-gateway"
}

resource "google_compute_route" "access_trusted_transit-default" {
  project = var.project_id

  name             = format("%s-%s-default", local._networks.access_trusted_transit.prefix, random_id.id.hex)
  network          = google_compute_network.access_trusted_transit.self_link
  tags             = [format("%s-%s-default", local._networks.access_trusted_transit.prefix, random_id.id.hex)]
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
resource "google_compute_subnetwork" "access_trusted_transit" {
  for_each = { for x in local._networks.access_trusted_transit.subnetworks : x.ip_cidr_range => x }

  project = var.project_id

  name    = format("%s-%s-%s", local._networks.access_trusted_transit.prefix, replace(each.value.ip_cidr_range, "//|\\./", "-"), random_id.id.hex)
  network = google_compute_network.access_trusted_transit.self_link

  private_ip_google_access = true
  ip_cidr_range            = each.value.ip_cidr_range
  region                   = each.value.region
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router
resource "google_compute_router" "access_trusted_transit" {
  for_each = toset(distinct(local._networks.access_trusted_transit.subnetworks.*.region))

  project = var.project_id

  name    = format("%s-%s", local._networks.access_trusted_transit.prefix, random_id.id.hex)
  network = google_compute_network.access_trusted_transit.self_link

  region = each.key
  bgp {
    # asn               = local._networks.access_trusted_transit.asn
    asn               = try(local._networks["access_trusted_transit"].regional_asn[each.key], local._networks["access_trusted_transit"].shared_asn, local._default_asn)
    advertise_mode    = "CUSTOM"
    advertised_groups = lookup(local._networks.access_trusted_transit, "advertise_local_subnets", false) ? ["ALL_SUBNETS"] : []

    dynamic "advertised_ip_ranges" {
      for_each = try(local._networks.access_trusted_transit.summary_ip_ranges[each.key], [])
      content {
        range = advertised_ip_ranges.value
      }
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat
resource "google_compute_router_nat" "access_trusted_transit" {
  for_each = toset(distinct([for subnetwork in local._networks["access_trusted_transit"].subnetworks : subnetwork.region if(try(local._networks["access_trusted_transit"].cloud_nat_all_subnets, false) || try(contains(subnetwork.tags, "cloud_nat"),false))]))

  project = var.project_id

  name   = format("%s-%s", local._networks.access_trusted_transit.prefix, random_id.id.hex)
  router = google_compute_router.access_trusted_transit[each.key].name
  region = google_compute_router.access_trusted_transit[each.key].region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  depends_on = [
    google_compute_router.access_trusted_transit
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_interface
resource "google_compute_router_interface" "access_trusted_transit-appliance-nic0" {
  for_each = { for x in local._networks.access_trusted_transit.subnetworks : x.ip_cidr_range => x if contains(try(x.tags, []), "network_appliance") }

  project = var.project_id

  name               = format("%s-%s-%s", local._networks.access_trusted_transit.prefix, format("nic%02d", 0), random_id.id.hex)
  router             = google_compute_router.access_trusted_transit[each.value.region].name
  region             = each.value.region
  private_ip_address = cidrhost(google_compute_subnetwork.access_trusted_transit[each.key].ip_cidr_range, -3)
  subnetwork         = google_compute_subnetwork.access_trusted_transit[each.key].self_link
}

resource "google_compute_router_interface" "access_trusted_transit-appliance-nic1" {
  for_each = { for x in local._networks.access_trusted_transit.subnetworks : x.ip_cidr_range => x if contains(try(x.tags, []), "network_appliance") }

  project = var.project_id

  name                = format("%s-%s-%s", local._networks.access_trusted_transit.prefix, format("nic%02d", 1), random_id.id.hex)
  router              = google_compute_router.access_trusted_transit[each.value.region].name
  region              = each.value.region
  redundant_interface = google_compute_router_interface.access_trusted_transit-appliance-nic0[each.key].name
  private_ip_address  = cidrhost(google_compute_subnetwork.access_trusted_transit[each.key].ip_cidr_range, -4)
  subnetwork          = google_compute_subnetwork.access_trusted_transit[each.key].self_link
}

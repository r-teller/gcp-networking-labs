resource "google_compute_network" "distro_lan" {
  project                         = var.project_id
  name                            = format("%s-%s", local._networks.distro_lan.prefix, random_id.id.hex)
  delete_default_routes_on_create = true
  auto_create_subnetworks         = false

  routing_mode = "REGIONAL"
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/network_connectivity_hub
resource "google_network_connectivity_hub" "distro_lan" {
  project = var.project_id

  name = format("%s-%s", local._networks.distro_lan.prefix, random_id.id.hex)
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_response_policy
resource "google_dns_response_policy" "distro_lan" {
  project = var.project_id

  response_policy_name = format("%s-%s", local._networks.distro_lan.prefix, random_id.id.hex)

  networks {
    network_url = google_compute_network.distro_lan.id
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_response_policy_rule
resource "google_dns_response_policy_rule" "distro_lan-a" {
  project = var.project_id

  response_policy = google_dns_response_policy.distro_lan.response_policy_name
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

resource "google_dns_response_policy_rule" "distro_lan-cname" {
  project = var.project_id

  response_policy = google_dns_response_policy.distro_lan.response_policy_name
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
resource "google_compute_firewall" "distro_lan-allow_all" {
  project = var.project_id

  name    = format("%s-%s-allow-all", local._networks.distro_lan.prefix, random_id.id.hex)
  network = google_compute_network.distro_lan.self_link

  source_ranges      = ["0.0.0.0/0"]
  destination_ranges = []
  allow {
    protocol = "all"
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_route
resource "google_compute_route" "distro_lan-iap" {
  project = var.project_id

  name             = format("%s-%s-iap", local._networks.distro_lan.prefix, random_id.id.hex)
  network          = google_compute_network.distro_lan.self_link
  dest_range       = "35.235.240.0/20"
  next_hop_gateway = "default-internet-gateway"
}

resource "google_compute_route" "distro_lan-private" {
  project = var.project_id

  name             = format("%s-%s-private", local._networks.distro_lan.prefix, random_id.id.hex)
  network          = google_compute_network.distro_lan.self_link
  dest_range       = "199.36.153.8/30"
  next_hop_gateway = "default-internet-gateway"
}

resource "google_compute_route" "distro_lan-default" {
  project = var.project_id

  name             = format("%s-%s-default", local._networks.distro_lan.prefix, random_id.id.hex)
  network          = google_compute_network.distro_lan.self_link
  tags             = [format("%s-%s-default", local._networks.distro_lan.prefix, random_id.id.hex)]
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
resource "google_compute_subnetwork" "distro_lan" {
  for_each = { for x in local._networks.distro_lan.subnetworks : x.ip_cidr_range => x }

  project = var.project_id

  name    = format("%s-%s-%s", local._networks.distro_lan.prefix, replace(each.value.ip_cidr_range, "//|\\./", "-"), random_id.id.hex)
  network = google_compute_network.distro_lan.self_link

  private_ip_google_access = true
  ip_cidr_range            = each.value.ip_cidr_range
  region                   = each.value.region
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router
resource "google_compute_router" "distro_lan" {
  for_each = toset(distinct(local._networks.distro_lan.subnetworks.*.region))

  project = var.project_id

  name    = format("%s-%s", local._networks.distro_lan.prefix, random_id.id.hex)
  network = google_compute_network.distro_lan.self_link

  region = each.key
  bgp {
    # asn               = local._networks.distro_lan.asn
    asn               = try(local._networks["distro_lan"].regional_asn[each.key], local._networks["distro_lan"].shared_asn, local._default_asn)
    advertise_mode    = "CUSTOM"
    advertised_groups = lookup(local._networks.distro_lan, "advertise_local_subnets", false) ? ["ALL_SUBNETS"] : []

    dynamic "advertised_ip_ranges" {
      for_each = try(local._networks.distro_lan.summary_ip_ranges[each.key], [])
      content {
        range = advertised_ip_ranges.value
      }
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat
resource "google_compute_router_nat" "distro_lan" {
  for_each = toset(distinct(local._networks.distro_lan.subnetworks.*.region))

  project = var.project_id

  name   = format("%s-%s", local._networks.distro_lan.prefix, random_id.id.hex)
  router = google_compute_router.distro_lan[each.key].name
  region = google_compute_router.distro_lan[each.key].region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  depends_on = [
    google_compute_router.distro_lan
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_interface
resource "google_compute_router_interface" "distro_lan-appliance-nic0" {
  for_each = { for x in local._networks.distro_lan.subnetworks : x.ip_cidr_range => x if contains(try(x.tags, []), "network_appliance") }

  project = var.project_id

  name               = format("%s-%s-%s", local._networks.distro_lan.prefix, format("nic%02d", 0), random_id.id.hex)
  router             = google_compute_router.distro_lan[each.value.region].name
  region             = each.value.region
  private_ip_address = cidrhost(google_compute_subnetwork.distro_lan[each.key].ip_cidr_range, -3)
  subnetwork         = google_compute_subnetwork.distro_lan[each.key].self_link
}

resource "google_compute_router_interface" "distro_lan-appliance-nic1" {
  for_each = { for x in local._networks.distro_lan.subnetworks : x.ip_cidr_range => x if contains(try(x.tags, []), "network_appliance") }

  project = var.project_id

  name                = format("%s-%s-%s", local._networks.distro_lan.prefix, format("nic%02d", 1), random_id.id.hex)
  router              = google_compute_router.distro_lan[each.value.region].name
  region              = each.value.region
  redundant_interface = google_compute_router_interface.distro_lan-appliance-nic0[each.key].name
  private_ip_address  = cidrhost(google_compute_subnetwork.distro_lan[each.key].ip_cidr_range, -4)
  subnetwork          = google_compute_subnetwork.distro_lan[each.key].self_link
}

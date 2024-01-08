resource "google_compute_network" "core_wan" {
  project                         = var.project_id
  name                            = format("%s-%s", local._networks.core_wan.prefix, random_id.id.hex)
  delete_default_routes_on_create = true
  auto_create_subnetworks         = false

  routing_mode = "GLOBAL"
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/network_connectivity_hub
resource "google_network_connectivity_hub" "core_wan" {
  project = var.project_id

  name = format("%s-%s", local._networks.core_wan.prefix, random_id.id.hex)
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_response_policy
resource "google_dns_response_policy" "core_wan" {
  project = var.project_id

  response_policy_name = format("%s-%s", local._networks.core_wan.prefix, random_id.id.hex)

  networks {
    network_url = google_compute_network.core_wan.id
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_response_policy_rule
resource "google_dns_response_policy_rule" "core_wan-a" {
  project = var.project_id

  response_policy = google_dns_response_policy.core_wan.response_policy_name
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

resource "google_dns_response_policy_rule" "core_wan-cname" {
  project = var.project_id

  response_policy = google_dns_response_policy.core_wan.response_policy_name
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
resource "google_compute_firewall" "core_wan-allow_all" {
  project = var.project_id

  name    = format("%s-%s-allow-all", local._networks.core_wan.prefix, random_id.id.hex)
  network = google_compute_network.core_wan.self_link

  source_ranges      = ["0.0.0.0/0"]
  destination_ranges = []
  allow {
    protocol = "all"
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_route
resource "google_compute_route" "core_wan-iap" {
  project = var.project_id

  name             = format("%s-%s-iap", local._networks.core_wan.prefix, random_id.id.hex)
  network          = google_compute_network.core_wan.self_link
  dest_range       = "35.235.240.0/20"
  next_hop_gateway = "default-internet-gateway"
}

resource "google_compute_route" "core_wan-private" {
  project = var.project_id

  name             = format("%s-%s-private", local._networks.core_wan.prefix, random_id.id.hex)
  network          = google_compute_network.core_wan.self_link
  dest_range       = "199.36.153.8/30"
  next_hop_gateway = "default-internet-gateway"
}

resource "google_compute_route" "core_wan-default" {
  project = var.project_id

  name             = format("%s-%s-default", local._networks.core_wan.prefix, random_id.id.hex)
  network          = google_compute_network.core_wan.self_link
  tags             = [format("%s-%s-default", local._networks.core_wan.prefix, random_id.id.hex)]
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
resource "google_compute_subnetwork" "core_wan" {
  for_each = { for x in local._networks.core_wan.subnetworks : x.ip_cidr_range => x }

  project = var.project_id

  name    = format("%s-%s-%s", local._networks.core_wan.prefix, replace(each.value.ip_cidr_range, "//|\\./", "-"), random_id.id.hex)
  network = google_compute_network.core_wan.self_link

  private_ip_google_access = true
  ip_cidr_range            = each.value.ip_cidr_range
  region                   = each.value.region
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router
resource "google_compute_router" "core_wan" {
  for_each = toset(distinct(local._networks.core_wan.subnetworks.*.region))

  project = var.project_id

  name    = format("%s-%s", local._networks.core_wan.prefix, random_id.id.hex)
  network = google_compute_network.core_wan.self_link

  region = each.key
  bgp {
    asn               = try(local._networks["core_wan"].regional_asn[each.key], local._networks["core_wan"].shared_asn, local._default_asn)
    advertise_mode    = "CUSTOM"
    advertised_groups = lookup(local._networks.core_wan, "advertise_local_subnets", false) ? ["ALL_SUBNETS"] : []
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat
resource "google_compute_router_nat" "core_wan" {
  for_each = toset(distinct(local._networks.core_wan.subnetworks.*.region))

  project = var.project_id

  name   = format("%s-%s", local._networks.core_wan.prefix, random_id.id.hex)
  router = google_compute_router.core_wan[each.key].name
  region = google_compute_router.core_wan[each.key].region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  depends_on = [
    google_compute_router.core_wan
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_interface
resource "google_compute_router_interface" "core_wan-appliance-nic0" {
  for_each = { for x in local._networks.core_wan.subnetworks : x.ip_cidr_range => x if contains(try(x.tags, []), "network_appliance") }

  project = var.project_id

  name               = format("%s-%s-%s", local._networks.core_wan.prefix, format("nic%02d", 0), random_id.id.hex)
  router             = google_compute_router.core_wan[each.value.region].name
  region             = each.value.region
  private_ip_address = cidrhost(google_compute_subnetwork.core_wan[each.key].ip_cidr_range, -3)
  subnetwork         = google_compute_subnetwork.core_wan[each.key].self_link
}

resource "google_compute_router_interface" "core_wan-appliance-nic1" {
  for_each = { for x in local._networks.core_wan.subnetworks : x.ip_cidr_range => x if contains(try(x.tags, []), "network_appliance") }

  project = var.project_id

  name                = format("%s-%s-%s", local._networks.core_wan.prefix, format("nic%02d", 1), random_id.id.hex)
  router              = google_compute_router.core_wan[each.value.region].name
  region              = each.value.region
  redundant_interface = google_compute_router_interface.core_wan-appliance-nic0[each.key].name
  private_ip_address  = cidrhost(google_compute_subnetwork.core_wan[each.key].ip_cidr_range, -4)
  subnetwork          = google_compute_subnetwork.core_wan[each.key].self_link
}

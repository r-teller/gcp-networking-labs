locals {
  random_id  = var.random_id
  config_map = var.config_map[var.input.config_map_tag]
}


resource "google_compute_network" "network" {
  project                         = var.project_id
  name                            = format("%s-%s", local.config_map["prefix"], local.random_id.hex)
  delete_default_routes_on_create = true
  auto_create_subnetworks         = false

  routing_mode = var.input.routing_mode
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_response_policy
resource "google_dns_response_policy" "response_policy" {
  count = (
    var.input.enable_private_googleapis ||
    var.input.enable_restriced_googleapis
  ) ? 1 : 0
  project = var.project_id

  response_policy_name = format("%s-%s", local.config_map["prefix"], local.random_id.hex)

  networks {
    network_url = google_compute_network.network.id
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_response_policy_rule
resource "google_dns_response_policy_rule" "response_policy-a-private" {
  count = var.input.enable_private_googleapis ? 1 : 0

  project = var.project_id

  response_policy = google_dns_response_policy.response_policy[0].response_policy_name
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

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_response_policy_rule
resource "google_dns_response_policy_rule" "response_policy-a-restricted" {
  count = var.input.enable_restriced_googleapis ? 1 : 0

  project = var.project_id

  response_policy = google_dns_response_policy.response_policy[0].response_policy_name
  rule_name       = "restricted-googleapis-com"
  dns_name        = "restricted.googleapis.com."

  local_data {
    local_datas {
      name = "restricted.googleapis.com."
      type = "A"
      ttl  = 300
      rrdatas = [
        "199.36.153.4",
        "199.36.153.5",
        "199.36.153.6",
        "199.36.153.7"
      ]
    }
  }
}

resource "google_dns_response_policy_rule" "response_policy-cname" {
  count = (var.input.enable_private_googleapis || var.input.enable_restriced_googleapis) ? 1 : 0

  project = var.project_id

  response_policy = google_dns_response_policy.response_policy[0].response_policy_name
  rule_name       = "star-googleapis-com"
  dns_name        = "*.googleapis.com."

  local_data {
    local_datas {
      name    = "*.googleapis.com."
      type    = "CNAME"
      ttl     = 300
      rrdatas = var.input.enable_restriced_googleapis ? ["restricted.googleapis.com."] : var.input.enable_private_googleapis ? ["private.googleapis.com."] : null
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall
resource "google_compute_firewall" "firewall-allow_all" {
  count   = local.config_map["firewall_rules"].allow_all ? 1 : 0
  project = var.project_id

  name    = format("%s-%s-allow-all", local.config_map["prefix"], local.random_id.hex)
  network = google_compute_network.network.self_link

  source_ranges = [
    "0.0.0.0/0",
  ]
  destination_ranges = []
  allow {
    protocol = "all"
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall
resource "google_compute_firewall" "firewall-rfc1918" {
  count   = local.config_map["firewall_rules"].allow_rfc1918 ? 1 : 0
  project = var.project_id

  name    = format("%s-%s-allow-rfc1918", local.config_map["prefix"], local.random_id.hex)
  network = google_compute_network.network.self_link

  source_ranges = [
    "192.168.0.0/16",
    "172.16.0.0/12",
    "10.0.0.0/8",
  ]
  destination_ranges = []
  allow {
    protocol = "all"
  }
}

resource "google_compute_firewall" "firewall-iap" {
  count   = local.config_map["firewall_rules"].allow_iap ? 1 : 0
  project = var.project_id

  name    = format("%s-%s-allow-iap", local.config_map["prefix"], local.random_id.hex)
  network = google_compute_network.network.self_link

  source_ranges = [
    "35.235.240.0/20",
  ]
  destination_ranges = []
  allow {
    protocol = "all"
  }
}


# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_route
resource "google_compute_route" "route-iap" {
  project = var.project_id

  name = format("%s-%s-iap", local.config_map["prefix"], local.random_id.hex)

  network          = google_compute_network.network.self_link
  dest_range       = "35.235.240.0/20"
  next_hop_gateway = "default-internet-gateway"
}

resource "google_compute_route" "route-private" {
  project = var.project_id

  name             = format("%s-%s-private-apis", local.config_map["prefix"], local.random_id.hex)
  network          = google_compute_network.network.self_link
  dest_range       = "199.36.153.8/30"
  next_hop_gateway = "default-internet-gateway"
}

resource "google_compute_route" "route-default" {
  project = var.project_id

  name             = format("%s-%s-default", local.config_map["prefix"], local.random_id.hex)
  network          = google_compute_network.network.self_link
  tags             = [format("%s-%s-default", local.config_map["prefix"], local.random_id.hex)]
  dest_range       = "0.0.0.0/0"
  priority         = 1000
  next_hop_gateway = "default-internet-gateway"
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
resource "google_compute_subnetwork" "subnetwork" {
  for_each = { for x in local.config_map["subnetworks"] : x.ip_cidr_range => x }

  project = var.project_id

  name    = format("%s-%s-%s", local.config_map["prefix"], replace(each.value.ip_cidr_range, "//|\\./", "-"), local.random_id.hex)
  network = google_compute_network.network.self_link

  private_ip_google_access = true
  ip_cidr_range            = each.value.ip_cidr_range
  region                   = each.value.region

  dynamic "secondary_ip_range" {
    for_each = try(toset(each.value.secondary_ip_ranges), [])
    content {
      range_name    = format("%s-%s-%s", local.config_map["prefix"], replace(secondary_ip_range.value, "//|\\./", "-"), local.random_id.hex)
      ip_cidr_range = secondary_ip_range.value
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router
resource "google_compute_router" "router" {
  for_each = toset(distinct(local.config_map["subnetworks"].*.region))

  project = var.project_id

  name    = format("%s-%s", local.config_map["prefix"], local.random_id.hex)
  network = google_compute_network.network.self_link

  region = each.key

  bgp {
    asn = coalesce(
      try(local.config_map.regional_asn[each.key], null),
      local.config_map.shared_asn,
      var.default_asn
    )
    advertise_mode    = "CUSTOM"
    advertised_groups = lookup(local.config_map, "advertise_local_subnets", false) ? ["ALL_SUBNETS"] : []

    dynamic "advertised_ip_ranges" {
      for_each = try(local.config_map.summary_ip_ranges[each.key], [])
      content {
        range = advertised_ip_ranges.value
      }
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat
resource "google_compute_router_nat" "router_nat" {
  for_each = toset(distinct([
    for subnetwork in local.config_map["subnetworks"] : subnetwork.region if(
      try(local.config_map["cloud_nat_all_subnets"], false) ||
    try(contains(subnetwork.tags, "cloud_nat"), false))])
  )

  project = var.project_id

  name   = format("%s-%s", local.config_map["prefix"], local.random_id.hex)
  router = google_compute_router.router[each.key].name
  region = google_compute_router.router[each.key].region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = try(local.config_map["cloud_nat_all_subnets"], false) ? "ALL_SUBNETWORKS_ALL_IP_RANGES" : "LIST_OF_SUBNETWORKS"

  dynamic "subnetwork" {
    for_each = [for subnetwork in local.config_map["subnetworks"] : format("%s-%s-%s", local.config_map["prefix"], replace(subnetwork.ip_cidr_range, "//|\\./", "-"), local.random_id.hex) if(
      subnetwork.region == each.key &&
      contains(subnetwork.tags, "cloud_nat") &&
      !(try(local.config_map.cloud_nat_all_subnets, false))
    )]

    content {
      name                    = subnetwork.value
      source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
    }
  }

  depends_on = [
    google_compute_router.router,
    google_compute_subnetwork.subnetwork,
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/network_connectivity_hub
resource "google_network_connectivity_hub" "connectivity_hub" {
  count = var.input.create_ncc_hub ? 1 : 0

  project = var.project_id

  name = format("%s-%s", local.config_map["prefix"], local.random_id.hex)

  depends_on = [
    google_compute_network.network
  ]
}


# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_interface
resource "google_compute_router_interface" "router_interface-nic0" {
  for_each = { for x in local.config_map["subnetworks"] : x.ip_cidr_range => x if(contains(x.tags, "network_appliance") && var.input.create_ncc_hub) }

  project = var.project_id

  name               = format("%s-%s-%s", local.config_map["prefix"], format("nic%02d", 0), local.random_id.hex)
  router             = google_compute_router.router[each.value.region].name
  region             = each.value.region
  private_ip_address = cidrhost(google_compute_subnetwork.subnetwork[each.key].ip_cidr_range, -3)
  subnetwork         = google_compute_subnetwork.subnetwork[each.key].self_link
}

resource "google_compute_router_interface" "router_interface-nic1" {
  for_each = { for x in local.config_map["subnetworks"] : x.ip_cidr_range => x if(contains(x.tags, "network_appliance") && var.input.create_ncc_hub) }

  project = var.project_id

  name                = format("%s-%s-%s", local.config_map["prefix"], format("nic%02d", 1), local.random_id.hex)
  router              = google_compute_router.router[each.value.region].name
  region              = each.value.region
  redundant_interface = google_compute_router_interface.router_interface-nic0[each.key].name
  private_ip_address  = cidrhost(google_compute_subnetwork.subnetwork[each.key].ip_cidr_range, -4)
  subnetwork          = google_compute_subnetwork.subnetwork[each.key].self_link
}

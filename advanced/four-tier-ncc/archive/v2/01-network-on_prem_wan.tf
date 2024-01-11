resource "google_compute_network" "on_prem_wan" {
  project                         = var.project_id
  name                            = format("%s-%s", local._networks.on_prem_wan.prefix, random_id.id.hex)
  delete_default_routes_on_create = true
  auto_create_subnetworks         = false

  routing_mode = "REGIONAL"
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_response_policy
resource "google_dns_response_policy" "on_prem_wan" {
  project = var.project_id

  response_policy_name = format("%s-%s", local._networks.on_prem_wan.prefix, random_id.id.hex)

  networks {
    network_url = google_compute_network.on_prem_wan.id
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_response_policy_rule
resource "google_dns_response_policy_rule" "on_prem_wan-a" {
  project = var.project_id

  response_policy = google_dns_response_policy.on_prem_wan.response_policy_name
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

resource "google_dns_response_policy_rule" "on_prem_wan-cname" {
  project = var.project_id

  response_policy = google_dns_response_policy.on_prem_wan.response_policy_name
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
resource "google_compute_firewall" "on_prem_wan-allow_all" {
  project = var.project_id

  name    = format("%s-%s-allow-all", local._networks.on_prem_wan.prefix, random_id.id.hex)
  network = google_compute_network.on_prem_wan.self_link

  source_ranges      = ["0.0.0.0/0"]
  destination_ranges = []
  allow {
    protocol = "all"
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_route
resource "google_compute_route" "on_prem_wan-iap" {
  project = var.project_id

  name             = format("%s-%s-iap", local._networks.on_prem_wan.prefix, random_id.id.hex)
  network          = google_compute_network.on_prem_wan.self_link
  dest_range       = "35.235.240.0/20"
  next_hop_gateway = "default-internet-gateway"
}

resource "google_compute_route" "on_prem_wan-private" {
  project = var.project_id

  name             = format("%s-%s-private", local._networks.on_prem_wan.prefix, random_id.id.hex)
  network          = google_compute_network.on_prem_wan.self_link
  dest_range       = "199.36.153.8/30"
  next_hop_gateway = "default-internet-gateway"
}

resource "google_compute_route" "on_prem_wan-default" {
  project = var.project_id

  name             = format("%s-%s-default", local._networks.on_prem_wan.prefix, random_id.id.hex)
  network          = google_compute_network.on_prem_wan.self_link
  tags             = [format("%s-%s-default", local._networks.on_prem_wan.prefix, random_id.id.hex)]
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
resource "google_compute_subnetwork" "on_prem_wan" {
  for_each = { for x in local._networks.on_prem_wan.subnetworks : x.ip_cidr_range => x }

  project = var.project_id

  name    = format("%s-%s-%s", local._networks.on_prem_wan.prefix, replace(each.value.ip_cidr_range, "//|\\./", "-"), random_id.id.hex)
  network = google_compute_network.on_prem_wan.self_link

  private_ip_google_access = true
  ip_cidr_range            = each.value.ip_cidr_range
  region                   = each.value.region
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router
resource "google_compute_router" "on_prem_wan" {
  for_each = toset(distinct(local._networks.on_prem_wan.subnetworks.*.region))

  project = var.project_id

  name    = format("%s-%s", local._networks.on_prem_wan.prefix, random_id.id.hex)
  network = google_compute_network.on_prem_wan.self_link

  region = each.key
  bgp {
    asn               = try(local._networks["on_prem_wan"].regional_asn[each.key], local._networks["on_prem_wan"].shared_asn, local._default_asn)
    advertise_mode    = "CUSTOM"
    advertised_groups = lookup(local._networks.on_prem_wan, "advertise_local_subnets", false) ? ["ALL_SUBNETS"] : []
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat
resource "google_compute_router_nat" "on_prem_wan" {
  for_each = toset(distinct([for subnetwork in local._networks["on_prem_wan"].subnetworks : subnetwork.region if(try(local._networks["on_prem_wan"].cloud_nat_all_subnets, false) || try(contains(subnetwork.tags, "cloud_nat"), false))]))
  #  toset(distinct(local._networks.core_wan.subnetworks.*.region))
  project = var.project_id

  name   = format("%s-%s", local._networks.on_prem_wan.prefix, random_id.id.hex)
  router = google_compute_router.on_prem_wan[each.key].name
  region = google_compute_router.on_prem_wan[each.key].region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = try(local._networks["on_prem_wan"].cloud_nat_all_subnets, false) ? "ALL_SUBNETWORKS_ALL_IP_RANGES" : "LIST_OF_SUBNETWORKS"

  dynamic "subnetwork" {
    for_each = [for subnetwork in local._networks["on_prem_wan"].subnetworks : format("%s-%s-%s", local._networks.on_prem_wan["prefix"], replace(subnetwork.ip_cidr_range, "//|\\./", "-"), random_id.id.hex) if(subnetwork.region == each.key && try(contains(subnetwork.tags, "cloud_nat"), false) && !(try(local._networks["on_prem_wan"].cloud_nat_all_subnets, false)))]
    content {
      name                    = subnetwork.value
      source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
    }
  }

  depends_on = [
    google_compute_router.on_prem_wan,
    google_compute_subnetwork.on_prem_wan,
  ]
}

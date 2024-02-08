resource "local_file" "init_cfg" {
  for_each = { for k, v in local.map : k => v if(var.input.bootstrap.enabled && var.input.bootstrap.output_local) }

  filename = format("./local_config/%s/config/init-cfg.txt", each.value.name)

  content = templatefile("${path.module}/templatefile/init-cfg.tmpl",
    {
      "redis-config" : try(var.input.regional_redis[each.value.region], null)
      "op-command-modes" : var.input.mgmt_interface_swap ? "mgmt-interface-swap" : ""
      "plugin-op-commands" : var.input.plugin_op_commands != null ? join(",", [for k, v in var.input.plugin_op_commands : format("%s:%s", k, v)]) : ""
    }
  )
}

resource "google_storage_bucket_object" "init_cfg" {
  for_each = { for k, v in local.map : k => v if(var.input.bootstrap.enabled && var.input.bootstrap.output_gcs) }

  name = format("%s/config/init-cfg.txt", each.value.name)

  content = templatefile("${path.module}/templatefile/init-cfg.tmpl",
    {
      "redis-config" : try(var.input.regional_redis[each.value.region], null)
      "op-command-modes" : var.input.mgmt_interface_swap ? "mgmt-interface-swap" : ""
      "plugin-op-commands" : var.input.plugin_op_commands != null ? join(",", [for k, v in var.input.plugin_op_commands : format("%s:%s", k, v)]) : ""
    }
  )
  bucket = var.bucket_name
}

resource "local_file" "bootstrap_xml" {
  for_each = { for k1, v1 in local.map : k1 => merge(v1, {
    subnetworks = { for k2, v2 in v1.subnetworks : k2 => merge(v2,
      {
        ipv4_address : google_compute_address.internal_addresses[k2].address
        ipv4_prefix : split("/", v2.cidr_range)[1]
        bgp_peers : {
          (v2.network_prefix) = {
            (format("%s-nic0", v2.network_prefix)) = {
              interface     = v2.ethernet
              local_address = google_compute_address.internal_addresses[k2].address
              peer_address  = cidrhost(v2.cidr_range, -4),
              peer_asn = try(
                var.config_map[v2.network].regional_asn[v1.region],
                var.config_map[v2.network].shared_asn,
                var.default_asn,
              ),
            }
            (format("%s-nic1", v2.network_prefix)) = {
              interface     = v2.ethernet
              local_address = google_compute_address.internal_addresses[k2].address
              peer_address  = cidrhost(v2.cidr_range, -3),
              peer_asn = try(
                var.config_map[v2.network].regional_asn[v1.region],
                var.config_map[v2.network].shared_asn,
                var.default_asn,
              ),
            }
          }
        }
      }) if v2.ethernet != null
    }
    management_address = one([for k2, v2 in v1.subnetworks : google_compute_address.internal_addresses[k2].address if v2.ethernet == null])
  }) if(var.input.bootstrap.enabled && var.input.bootstrap.output_local) }

  filename = format("./local_config/%s/config/bootstrap.xml", each.value.name)

  content = templatefile("${path.module}/templatefile/bootstrap_v11_1_0.tmpl",
    {
      name : each.value.shortname,
      interfaces : each.value.subnetworks,
      bootstrap_bgp : var.input.bootstrap.bgp_enabled,
      asn : try(
        var.input.regional_asn[each.value.region],
        var.input.shared_asn,
        var.default_asn,
      )
      neighbors : merge(values(each.value.subnetworks).*.bgp_peers...)
      management_address : each.value.management_address
    }
  )
}

resource "google_storage_bucket_object" "bootstrap" {
  for_each = { for k1, v1 in local.map : k1 => merge(v1, {
    subnetworks = { for k2, v2 in v1.subnetworks : k2 => merge(v2,
      {
        ipv4_address : google_compute_address.internal_addresses[k2].address
        ipv4_prefix : split("/", v2.cidr_range)[1]
        bgp_peers : {
          (v2.network_prefix) = {
            (format("%s-nic0", v2.network_prefix)) = {
              interface     = v2.ethernet
              local_address = google_compute_address.internal_addresses[k2].address
              peer_address  = cidrhost(v2.cidr_range, -4),
              peer_asn = try(
                var.config_map[v2.network].regional_asn[v1.region],
                var.config_map[v2.network].shared_asn,
                var.default_asn,
              ),
            }
            (format("%s-nic1", v2.network_prefix)) = {
              interface     = v2.ethernet
              local_address = google_compute_address.internal_addresses[k2].address
              peer_address  = cidrhost(v2.cidr_range, -3),
              peer_asn = try(
                var.config_map[v2.network].regional_asn[v1.region],
                var.config_map[v2.network].shared_asn,
                var.default_asn,
              ),
            }
          }
        }
      }) if v2.ethernet != null
    }
    management_address = one([for k2, v2 in v1.subnetworks : google_compute_address.internal_addresses[k2].address if v2.ethernet == null])
  }) if(var.input.bootstrap.enabled && var.input.bootstrap.output_gcs) }

  name = format("%s/config/bootstrap.xml", each.value.name)

  content = templatefile("${path.module}/templatefile/bootstrap_v11_1_0.tmpl",
    {
      name : each.value.shortname,
      interfaces : each.value.subnetworks,
      bootstrap_bgp : var.input.bootstrap.bgp_enabled,
      asn : try(
        var.input.regional_asn[each.value.region],
        var.input.shared_asn,
        var.default_asn,
      )
      neighbors : merge(values(each.value.subnetworks).*.bgp_peers...)
      management_address : each.value.management_address
    }
  )

  bucket = var.bucket_name
}

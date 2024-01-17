resource "local_file" "config_boot" {
  for_each = { for k1, v1 in local.map : k1 => v1 if(var.input.bootstrap.enabled && var.input.bootstrap.output_local) }

  filename = format("./local_config/%s/config.boot", each.value.name)

  content = templatefile("${path.module}/templatefile/config.boot.tmpl",
    {
      "name" : each.value.name,
      "interfaces" : each.value.subnetworks,
      "asn" : try(
        var.input.regional_asn[each.value.region],
        var.input.shared_asn,
        var.default_asn,
      ),
      "neighbors" : flatten([for k2, v2 in each.value.subnetworks : [
        {
          peer_address = cidrhost(v2.cidr_range, -4),
          peer_asn = try(
            var.config_map[v2.network].regional_asn[each.value.region],
            var.config_map[v2.network].shared_asn,
            var.default_asn,
          ),
        },
        {
          peer_address = cidrhost(v2.cidr_range, -3),
          peer_asn = try(
            var.config_map[v2.network].regional_asn[each.value.region],
            var.config_map[v2.network].shared_asn,
            var.default_asn,
          ),
        }
      ]])
    }
  )
}

resource "google_storage_bucket_object" "config_boot" {
  for_each = { for k1, v1 in local.map : k1 => v1 if(var.input.bootstrap.enabled && var.input.bootstrap.output_gcs) }

  name = format("%s/config.boot", each.value.name)

  content = templatefile("${path.module}/templatefile/config.boot.tmpl",
    {
      "name" : each.value.name,
      "interfaces" : each.value.subnetworks,
      "asn" : try(
        var.input.regional_asn[each.value.region],
        var.input.shared_asn,
        var.default_asn,
      ),
      "neighbors" : flatten([for k2, v2 in each.value.subnetworks : [
        {
          peer_address = cidrhost(v2.cidr_range, -4),
          peer_asn = try(
            var.config_map[v2.network].regional_asn[each.value.region],
            var.config_map[v2.network].shared_asn,
            var.default_asn,
          ),
        },
        {
          peer_address = cidrhost(v2.cidr_range, -3),
          peer_asn = try(
            var.config_map[v2.network].regional_asn[each.value.region],
            var.config_map[v2.network].shared_asn,
            var.default_asn,
          ),
        }
      ]])
    }
  )
  bucket = var.bucket_name
}

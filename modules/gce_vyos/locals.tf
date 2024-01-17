locals {
  random_id = var.random_id
  continent_short_name = {
    asia         = "az"
    australia    = "au"
    europe       = "eu"
    northamerica = "na"
    southamerica = "sa"
    us           = "us"
    me           = "me"
  }

  # service_account = var.service_account != null ? var.service_account : data.google_compute_default_service_account.compute_default_service_account.email

  _map = merge([
    for k1, v1 in var.input.zones : {
      for idx in range(v1) :
      format("%s-vyos-%s-%02d", var.input.name_prefix, k1, idx) => {
        name = format("%s-vyos-%s-%02d-%s",
          var.input.name_prefix,
          join("", [
            local.continent_short_name[split("-", k1)[0]],
            replace(join("", slice(split("-", k1), 1, 3)), "/(n)orth|(s)outh|(e)ast|(w)est|(c)entral/", "$1$2$3$4$5")
          ]),
          idx,
          local.random_id.hex
        )
        machine_type    = var.input.machine_type
        zone            = k1
        region          = regex("^(.*)-.", k1)[0]
        service_account = coalesce(var.input.service_account, data.google_compute_default_service_account.compute_default_service_account.email)
      }
    }
  ]...)


  #   bucket_object = format("core_wan-to-distro_lan-vyos-%s.conf", local._regions[v1.region])
  map = { for k1, v1 in local._map : k1 => merge(v1, {
    subnetworks = { for k2, v2 in var.input.interfaces : format("%s-%s", k1, k2) => {
      nic = format("eth%d", k2)
      cidr_range = [
        for subnetwork in var.config_map[v2.config_map_tag].subnetworks :
        subnetwork.ip_cidr_range if(
          subnetwork.region == v1.region &&
          contains(subnetwork.tags, v2.subnetwork_tag)
        )
      ][0]

      network_prefix = var.config_map[v2.config_map_tag].prefix
      region         = v1.region
      ncc_spoke = format("%s-vyos-%s",
        var.config_map[v2.config_map_tag].prefix,
        module.utils.region_short_name_map[v1.region]
      )

      network          = v2.config_map_tag
      use_ncc_hub      = v2.use_ncc_hub
      external_enabled = v2.external_enabled

      subnetwork = format(
        "%s-%s", var.config_map[v2.config_map_tag].prefix,
        replace(
          [
            for subnetwork in var.config_map[v2.config_map_tag].subnetworks :
            subnetwork.ip_cidr_range if(
              subnetwork.region == v1.region &&
              contains(subnetwork.tags, v2.subnetwork_tag)
            )
          ][0],
          "//|\\./", "-"
        )
      )
      }
    }
    })
  }
}

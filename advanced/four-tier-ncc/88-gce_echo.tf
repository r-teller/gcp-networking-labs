resource "null_resource" "echo" {
  depends_on = [
    module.network-access_trusted_aa00,
    module.network-access_trusted_ab00,
  ]
}

locals {
  echo = {
    networks     = ["access_trusted_aa00", "access_trusted_ab00"]
    machine_type = "e2-micro"
    zones = {
      "us-east4-a" = 1
      "us-west1-a" = 1
    }
  }

  _echo_map = merge([for x in setproduct(local.echo.networks, keys(local.echo.zones)) : { for idx in range(local.echo.zones[x[1]]) : join("-", [x[0], x[1], idx]) => {
    zone             = x[1]
    key              = x[0]
    region           = regex("^(.*)-.", x[1])[0]
    prefix           = local._networks[x[0]].prefix
    subnetwork_index = try(index(local._networks[x[0]].subnetworks.*.region, regex("^(.*)-.", x[1])[0]), null)
    idx              = idx
  } }]...)

  echo_map = { for k, v in local._echo_map : k => merge(v, {
    name = format("%s-echo-%s-%02d-%s",
      v.prefix,
      join("", [
        local.continent_short_name[split("-", v.region)[0]],
        replace(join("", slice(split("-", v.zone), 1, 3)), "/(n)orth|(s)outh|(e)ast|(w)est|(c)entral/", "$1$2$3$4$5")
      ]),
      v.idx,
      random_id.id.hex
    )
    cidr_range = local._networks[v.key].subnetworks[v.subnetwork_index].ip_cidr_range
    subnetwork = format(
      "%s-%s-%s", local._networks[v.key].prefix,
      replace(local._networks[v.key].subnetworks[v.subnetwork_index].ip_cidr_range, "//|\\./", "-"),
      random_id.id.hex
    )
  }) if v.subnetwork_index != null }
}

resource "google_compute_instance" "echo" {
  for_each = local.echo_map
  project  = var.project_id

  name = each.value.name
  zone = each.value.zone
  tags = [
    format("%s-%s-default", each.value.prefix, random_id.id.hex)
  ]

  boot_disk {
    auto_delete = true

    initialize_params {
      image = "projects/cos-cloud/global/images/cos-stable-109-17800-66-27"
      size  = 10
      type  = "pd-balanced"
    }

    mode = "READ_WRITE"
  }

  labels = {
    container-vm = "cos-stable-109-17800-66-27"
    goog-ec-src  = "vm_add-tf"
  }

  machine_type = "e2-small"

  metadata = {
    gce-container-declaration = yamlencode({
      "spec" : {
        "containers" : [
          {
            "name" : "instance-1",
            "image" : "rteller/echo:latest",
            "stdin" : false,
            "tty" : false
          }
        ],
        "restartPolicy" : "Always"
      }
    })
  }

  network_interface {
    subnetwork_project = var.project_id
    subnetwork         = each.value.subnetwork
    # subnetwork = google_compute_subnetwork.shared_aa00_prod["10.0.96.0/27"].self_link
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
    provisioning_model  = "STANDARD"
  }

  service_account {
    scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/trace.append"
    ]
  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = false
    enable_vtpm                 = true
  }

  lifecycle {
    ignore_changes = [
      metadata["ssh-keys"]
    ]
  }

  depends_on = [
    null_resource.echo
  ]
}

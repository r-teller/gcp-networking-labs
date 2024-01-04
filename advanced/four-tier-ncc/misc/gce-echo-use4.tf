resource "google_compute_instance" "shared_echo_use4" {
  count   = 1
  project = var.project_id

  name = format("shared-prod-echo-%s-%02d-%s", "use4", count.index, random_id.id.hex)
  zone = "us-east4-a"
  tags = [
    format("core-wan-%s-default", random_id.id.hex)
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
    # network_ip = cidrhost(google_compute_subnetwork.core_wan_usw1.ip_cidr_range, -5)
    subnetwork = google_compute_subnetwork.shared_aa00_prod["10.0.96.0/27"].self_link
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

  depends_on = [google_compute_subnetwork.shared_aa00_prod]
}

resource "google_compute_instance" "trusted_echo_use4" {
  count   = 1
  project = var.project_id

  name = format("trusted-prod-echo-%s-%02d-%s", "use4", count.index, random_id.id.hex)
  zone = "us-east4-a"
  tags = [
    format("core-wan-%s-default", random_id.id.hex)
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
    
    # network_ip = cidrhost(google_compute_subnetwork.core_wan_usw1.ip_cidr_range, -5)
    subnetwork = google_compute_subnetwork.access_trusted_aa00["172.24.0.0/24"].self_link
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

  depends_on = [google_compute_subnetwork.shared_aa00_prod]
}


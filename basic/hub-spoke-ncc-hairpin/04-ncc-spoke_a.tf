locals {
  spoke_a_us_west1_local_bgp = {
    count = 1
    asn   = 4213300000
    network_summary_ranges = jsonencode([
      "0.0.0.0/0", "10.0.224.0/21"
    ])
  }
  spoke_a_us_west1_remote_bgp = {
    asn  = google_compute_router.spoke_a_us_west1_router.bgp[0].asn
    name = replace(google_compute_router.spoke_a_us_west1_router.name, "-", "_")
    nic0 = google_compute_router_interface.router_interface-nic0-us-west1.private_ip_address
    nic1 = google_compute_router_interface.router_interface-nic1-us-west1.private_ip_address
  }

  spoke_a_us_east4_local_bgp = {
    asn = 4203300000
    network_summary_ranges = jsonencode([
      "0.0.0.0/0", "0.0.0.0/1", "10.0.224.0/21"
    ])
  }
  spoke_a_us_east4_remote_bgp = {
    asn  = google_compute_router.spoke_a_us_east4_router.bgp[0].asn
    name = replace(google_compute_router.spoke_a_us_east4_router.name, "-", "_")
    nic0 = google_compute_router_interface.router_interface-nic0-us-east4.private_ip_address
    nic1 = google_compute_router_interface.router_interface-nic1-us-east4.private_ip_address
  }
}


# Instance in us-west1-a
resource "google_compute_instance" "gce-spoke_a-usw1a" {
  count        = local.spoke_a_us_west1_local_bgp.count
  name         = format("spoke-a-usw1a-%02d-${random_id.id.hex}", count.index)
  machine_type = var.machine_type
  zone         = "us-west1-a"
  project      = var.project_id

  metadata = {
    enable-oslogin         = "FALSE"
    serial-port-enable     = "TRUE"
    network-summary-ranges = local.spoke_a_us_west1_local_bgp.network_summary_ranges
    user-data              = <<EOH
    #cloud-config
    vyos_config_commands:
    - set policy route-map PERMIT-IGP-EXPORT rule 10 action 'permit'
    - set policy route-map PERMIT-IGP-EXPORT rule 10 match origin 'igp'
    - set policy route-map PERMIT-IGP-EXPORT rule 20 action 'deny'
    - set protocols bgp ${local.spoke_a_us_west1_local_bgp.asn} peer-group ${local.spoke_a_us_west1_remote_bgp.name} remote-as '${local.spoke_a_us_west1_remote_bgp.asn}'
    - set protocols bgp ${local.spoke_a_us_west1_local_bgp.asn} peer-group ${local.spoke_a_us_west1_remote_bgp.name} address-family ipv4-unicast soft-reconfiguration inbound
    - set protocols bgp ${local.spoke_a_us_west1_local_bgp.asn} peer-group ${local.spoke_a_us_west1_remote_bgp.name} address-family ipv4-unicast route-map export 'PERMIT-IGP-EXPORT'
    - set protocols bgp ${local.spoke_a_us_west1_local_bgp.asn} neighbor ${local.spoke_a_us_west1_remote_bgp.nic0} peer-group '${local.spoke_a_us_west1_remote_bgp.name}'
    - set protocols bgp ${local.spoke_a_us_west1_local_bgp.asn} neighbor ${local.spoke_a_us_west1_remote_bgp.nic1} peer-group '${local.spoke_a_us_west1_remote_bgp.name}'
    - set system task-scheduler task update-summary-advertisements crontab-spec '*/5 * * * *'
    - set system task-scheduler task update-summary-advertisements executable path '/opt/vyatta/etc/config/scripts/vyos-cron-summary-advertisements.script'
    write_files:
    - path: /opt/vyatta/etc/config/scripts/vyos-cron-summary-advertisements.script
      owner: root:vyattacfg
      permissions: '0775'
      content: |
        #!/bin/vbash
        source /opt/vyatta/etc/functions/script-template

        # Fetch the current operational state CIDR ranges from BGP configuration
        # Using the specific output format mentioned
        operational_state_cidrs=$(run show config commands | grep -e 'set protocols bgp [0-9]* address-family ipv4-unicast network' | awk '{print $NF}')

        # Convert the space-separated CIDRs into an array
        readarray -t operational_state_array <<< $(echo $operational_state_cidrs | tr ' ' '\n')

        # URL of the metadata endpoint
        METADATA_URL="http://metadata.google.internal/computeMetadata/v1/instance/attributes/network-summary-ranges"

        # Fetch CIDR ranges
        intended_state_cidrs=$(curl -s $METADATA_URL  -H "Metadata-Flavor: Google" | jq -r '.[]')
        
        # Convert intended state CIDRs into an array
        readarray -t intended_state_array <<< $(echo $intended_state_cidrs | tr ' ' '\n')
        

        # Determine changes: additions and deletions
        additions=$(/usr/bin/comm -23 <(echo "$${intended_state_array[@]}" | tr ' ' '\n' | sort) <(echo "$${operational_state_array[@]}" | tr ' ' '\n' | sort))
        deletions=$(echo "$${operational_state_array[@]}" | tr ' ' '\n' | sort | uniq | grep -vxFf <(echo "$${intended_state_array[@]}" | tr ' ' '\n' | sort | uniq))
        
        # Check if there are changes to be made
        if [[ -z "$additions" && -z "$deletions" ]]; then
            exit 0
        fi

        # Enter configuration mode
        configure

        # Add new CIDR ranges
        for cidr in $additions; do
            set protocols bgp ${local.spoke_a_us_west1_local_bgp.asn} address-family ipv4-unicast network $cidr
        done

        # Delete old CIDR ranges
        for cidr in $deletions; do
            delete protocols bgp ${local.spoke_a_us_west1_local_bgp.asn} address-family ipv4-unicast network $cidr
        done

        # Commit the changes and exit configuration mode if changes have been made
        if [[ -n "$additions" || -n "$deletions" ]]; then
            commit
            save
        fi
        exit
    EOH
  }

  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  can_ip_forward = true

  network_interface {
    network    = google_compute_network.spoke_a_vpc_network.id
    subnetwork = google_compute_subnetwork.spoke_a_us_west1_subnet.id
    nic_type   = "GVNIC"
  }
}


# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/network_connectivity_spoke
resource "google_network_connectivity_spoke" "ncc-spoke_a-gce-usw1" {
  count   = length(google_compute_instance.gce-spoke_a-usw1a) > 0 ? 1 : 0
  project = var.project_id

  name     = format("spoke-a-usw1-${random_id.id.hex}")
  hub      = google_network_connectivity_hub.spoke_a_ncc_hub.name
  location = "us-west1"

  linked_router_appliance_instances {
    site_to_site_data_transfer = true

    dynamic "instances" {
      for_each = length(google_compute_instance.gce-spoke_a-usw1a) > 0 ? range(length(google_compute_instance.gce-spoke_a-usw1a)) : []
      content {
        virtual_machine = google_compute_instance.gce-spoke_a-usw1a[instances.key].self_link
        ip_address      = google_compute_instance.gce-spoke_a-usw1a[instances.key].network_interface[0].network_ip
      }
    }
  }
}


# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_peer
resource "google_compute_router_peer" "peer-spoke_a-usw1-nic0" {
  count = length(google_compute_instance.gce-spoke_a-usw1a)

  project = var.project_id

  name      = format("spoke-a-usw1-%02d-to-nic%02d-${random_id.id.hex}", count.index, 0)
  router    = google_compute_router.spoke_a_us_west1_router.name
  region    = google_compute_router.spoke_a_us_west1_router.region
  interface = google_compute_router_interface.router_interface-nic0-us-west1.name

  peer_asn = local.spoke_a_us_west1_local_bgp.asn

  router_appliance_instance = google_compute_instance.gce-spoke_a-usw1a[count.index].self_link
  peer_ip_address           = google_compute_instance.gce-spoke_a-usw1a[count.index].network_interface[0].network_ip

  advertised_route_priority = 100

  depends_on = [google_network_connectivity_spoke.ncc-spoke_a-gce-usw1]
}

resource "google_compute_router_peer" "peer-spoke_a-usw1-nic1" {
  count = length(google_compute_instance.gce-spoke_a-usw1a)

  project = var.project_id

  name      = format("spoke-a-usw1-%02d-to-nic%02d-${random_id.id.hex}", count.index, 1)
  router    = google_compute_router.spoke_a_us_west1_router.name
  region    = google_compute_router.spoke_a_us_west1_router.region
  interface = google_compute_router_interface.router_interface-nic1-us-west1.name

  peer_asn = local.spoke_a_us_west1_local_bgp.asn

  router_appliance_instance = google_compute_instance.gce-spoke_a-usw1a[count.index].self_link
  peer_ip_address           = google_compute_instance.gce-spoke_a-usw1a[count.index].network_interface[0].network_ip

  advertised_route_priority = 100

  depends_on = [google_network_connectivity_spoke.ncc-spoke_a-gce-usw1]
}



# Instance in us-east4-a
resource "google_compute_instance" "gce-spoke_a-use4a" {
  count        = 1
  name         = format("spoke-a-use4a-%02d-${random_id.id.hex}", count.index)
  machine_type = var.machine_type
  zone         = "us-east4-a"
  project      = var.project_id

  metadata = {
    enable-oslogin         = "FALSE"
    serial-port-enable     = "TRUE"
    network-summary-ranges = local.spoke_a_us_east4_local_bgp.network_summary_ranges
    user-data              = <<EOH
    #cloud-config
    vyos_config_commands:
    - set protocols bgp ${local.spoke_a_us_east4_local_bgp.asn} peer-group ${local.spoke_a_us_east4_remote_bgp.name} remote-as '${local.spoke_a_us_east4_remote_bgp.asn}'
    - set protocols bgp ${local.spoke_a_us_east4_local_bgp.asn} peer-group ${local.spoke_a_us_east4_remote_bgp.name} address-family ipv4-unicast soft-reconfiguration inbound
    - set protocols bgp ${local.spoke_a_us_east4_local_bgp.asn} neighbor ${local.spoke_a_us_east4_remote_bgp.nic0} peer-group '${local.spoke_a_us_east4_remote_bgp.name}'
    - set protocols bgp ${local.spoke_a_us_east4_local_bgp.asn} neighbor ${local.spoke_a_us_east4_remote_bgp.nic1} peer-group '${local.spoke_a_us_east4_remote_bgp.name}'
    - set system task-scheduler task update-summary-advertisements crontab-spec '*/5 * * * *'
    - set system task-scheduler task update-summary-advertisements executable path '/opt/vyatta/etc/config/scripts/vyos-cron-summary-advertisements.script'
    write_files:
    - path: /opt/vyatta/etc/config/scripts/vyos-cron-summary-advertisements.script
      owner: root:vyattacfg
      permissions: '0775'
      content: |
        #!/bin/vbash
        source /opt/vyatta/etc/functions/script-template

        # Fetch the current operational state CIDR ranges from BGP configuration
        # Using the specific output format mentioned
        operational_state_cidrs=$(run show config commands | grep -e 'set protocols bgp [0-9]* address-family ipv4-unicast network' | awk '{print $NF}')

        # Convert the space-separated CIDRs into an array
        readarray -t operational_state_array <<< $(echo $operational_state_cidrs | tr ' ' '\n')

        # URL of the metadata endpoint
        METADATA_URL="http://metadata.google.internal/computeMetadata/v1/instance/attributes/network-summary-ranges"

        # Fetch CIDR ranges
        intended_state_cidrs=$(curl -s $METADATA_URL  -H "Metadata-Flavor: Google" | jq -r '.[]')
        
        # Convert intended state CIDRs into an array
        readarray -t intended_state_array <<< $(echo $intended_state_cidrs | tr ' ' '\n')
        

        # Determine changes: additions and deletions
        additions=$(/usr/bin/comm -23 <(echo "$${intended_state_array[@]}" | tr ' ' '\n' | sort) <(echo "$${operational_state_array[@]}" | tr ' ' '\n' | sort))
        deletions=$(echo "$${operational_state_array[@]}" | tr ' ' '\n' | sort | uniq | grep -vxFf <(echo "$${intended_state_array[@]}" | tr ' ' '\n' | sort | uniq))
        
        # Check if there are changes to be made
        if [[ -z "$additions" && -z "$deletions" ]]; then
            exit 0
        fi

        # Enter configuration mode
        configure

        # Add new CIDR ranges
        for cidr in $additions; do
            set protocols bgp ${local.spoke_a_us_east4_local_bgp.asn} address-family ipv4-unicast network $cidr
        done

        # Delete old CIDR ranges
        for cidr in $deletions; do
            delete protocols bgp ${local.spoke_a_us_east4_local_bgp.asn} address-family ipv4-unicast network $cidr
        done

        # Commit the changes and exit configuration mode if changes have been made
        if [[ -n "$additions" || -n "$deletions" ]]; then
            commit
            save
        fi
        exit
    EOH
  }

  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  can_ip_forward = true

  network_interface {
    network    = google_compute_network.spoke_a_vpc_network.id
    subnetwork = google_compute_subnetwork.spoke_a_us_east4_subnet.id
    nic_type   = "GVNIC"
  }
}


# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/network_connectivity_spoke
resource "google_network_connectivity_spoke" "ncc-spoke_a-gce-use4" {
  project = var.project_id

  name     = format("spoke-a-use4-${random_id.id.hex}")
  hub      = google_network_connectivity_hub.spoke_a_ncc_hub.name
  location = "us-east4"

  linked_router_appliance_instances {
    site_to_site_data_transfer = true

    dynamic "instances" {
      for_each = range(length(google_compute_instance.gce-spoke_a-use4a))
      content {
        virtual_machine = google_compute_instance.gce-spoke_a-use4a[instances.key].self_link
        ip_address      = google_compute_instance.gce-spoke_a-use4a[instances.key].network_interface[0].network_ip
      }
    }
  }
}


# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_peer
resource "google_compute_router_peer" "peer-spoke_a-use4-nic0" {
  count = length(google_compute_instance.gce-spoke_a-use4a)

  project = var.project_id

  name      = format("spoke-a-use4-%02d-to-nic%02d-${random_id.id.hex}", count.index, 0)
  router    = google_compute_router.spoke_a_us_east4_router.name
  region    = google_compute_router.spoke_a_us_east4_router.region
  interface = google_compute_router_interface.router_interface-nic0-us-east4.name

  peer_asn = local.spoke_a_us_east4_local_bgp.asn

  router_appliance_instance = google_compute_instance.gce-spoke_a-use4a[count.index].self_link
  peer_ip_address           = google_compute_instance.gce-spoke_a-use4a[count.index].network_interface[0].network_ip

  advertised_route_priority = 100
}

resource "google_compute_router_peer" "peer-spoke_a-use4-nic1" {
  count = length(google_compute_instance.gce-spoke_a-use4a)

  project = var.project_id

  name      = format("spoke-a-use4-%02d-to-nic%02d-${random_id.id.hex}", count.index, 1)
  router    = google_compute_router.spoke_a_us_east4_router.name
  region    = google_compute_router.spoke_a_us_east4_router.region
  interface = google_compute_router_interface.router_interface-nic1-us-east4.name

  peer_asn = local.spoke_a_us_east4_local_bgp.asn

  router_appliance_instance = google_compute_instance.gce-spoke_a-use4a[count.index].self_link
  peer_ip_address           = google_compute_instance.gce-spoke_a-use4a[count.index].network_interface[0].network_ip

  advertised_route_priority = 100
}

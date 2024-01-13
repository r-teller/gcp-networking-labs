module "network-on_prem_wan" {
  source = "../../modules/network"

  project_id = var.project_id
  config_map = local._networks
  input = {
    config_map_tag = "on_prem_wan"
    routing_mode   = "REGIONAL"
  }
  random_id = random_id.id
}

# module "network-example" {
#   source = "../../modules/network"

#   project_id = var.project_id
#   config_map = {
#     "example" : { prefix : "example", subnetworks : [{ region : "us-west1", ip_cidr_range : "192.168.255.0/24" }] }
#   }
#   input = {
#     config_map_tag = "example"
#     routing_mode   = "REGIONAL"
#   }
#   random_id = random_id.id
# }

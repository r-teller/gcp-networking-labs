# output "map" {
#   # value = merge(values(local.map).*.subnetworks...)
#   # value = { for k, v in merge(values(local.map).*.subnetworks...) : k => v if v.ncc_hub != null }
#   value = { for x in distinct(values(merge(values(local.map).*.subnetworks...))) : x.ncc_spoke => x if x.ncc_hub != null }
# }

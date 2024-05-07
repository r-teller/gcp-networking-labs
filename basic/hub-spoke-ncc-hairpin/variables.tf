variable "project_id" {
  type = string
}

variable "image" {
  type    = string
  default = "projects/sentrium-public/global/images/vyos-1-3-5-20231222143039"
}

variable "machine_type" {
  type    = string
  default = "n2-highcpu-4"
}

variable "vyos_user_data" {
  type    = string
  default = ""
}

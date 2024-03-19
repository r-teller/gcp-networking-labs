variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-west1"
}

variable "regions" {
  type    = list(string)
  default = ["us-west1"]
}

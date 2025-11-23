variable "env" { type = string }
variable "prefix" { type = string }
variable "location" { type = string }
variable "ci_object_id" {
  type    = string
  default = ""
}
variable "vnet_address_space" {
  type = list(string)
}

variable "aks_subnet_prefix" {
  type = list(string)
}
variable "node_vm_size" {}
variable "node_count" {}
variable "node_min_count" {}
variable "node_max_count" {}

variable "kubernetes_version" {
  type    = string
  default = ""
}

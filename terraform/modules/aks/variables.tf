variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "dns_prefix" { type = string }
variable "kubernetes_version" {
  type    = string
  default = ""
}
variable "log_analytics_workspace_id" {
  type = string
}
variable "node_pool_name" {
  type    = string
  default = "agentpool"
}
variable "node_vm_size" {
  type    = string
  default = "Standard_B2s"
}
variable "node_count" {
  type    = number
  default = 1
}
variable "node_min_count" {
  type    = number
  default = 1
}
variable "node_max_count" {
  type    = number
  default = 3
}
variable "node_auto_scaling" {
  type    = bool
  default = true
}
variable "node_os_disk_size_gb" {
  type    = number
  default = 128
}
variable "acr_id" { type = string }
variable "ci_object_id" {
  type    = string
  default = ""
}
variable "tags" {
  type    = map(string)
  default = {}
}
variable "subnet_id" {
  type = string
}

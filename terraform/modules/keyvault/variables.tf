variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tenant_id" { type = string }
variable "creator_object_id" {
  type        = string
  description = "Object ID of the identity that creates the Key Vault and needs full access."
}
variable "secret_name" {
  type    = string
  default = "app-insights-key"
}
variable "secret_value" { type = string }
variable "ci_object_id" {
  type    = string
  default = ""
}
variable "sku_name" {
  type    = string
  default = "standard"
}
variable "tags" {
  type    = map(string)
  default = {}
}

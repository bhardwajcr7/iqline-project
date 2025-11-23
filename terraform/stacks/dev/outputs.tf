output "acr_login_server" {
  value = module.acr.login_server
}
output "resource_group" {
  value = azurerm_resource_group.main.name
}
output "log_analytics_id" {
  value = module.loganalytics.law_id
}
output "app_insights_instrumentation_key" {
  value     = module.appinsights.instrumentation_key
  sensitive = true
}
output "key_vault_uri" {
  value = module.keyvault.key_vault_uri
}

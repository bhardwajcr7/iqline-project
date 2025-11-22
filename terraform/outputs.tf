output "resource_group" {
  value = azurerm_resource_group.rg.name
}
output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}
output "aks_name" {
  value = azurerm_kubernetes_cluster.aks.name
}
output "kv_name" {
  value = azurerm_key_vault.kv.name
}
output "app_insights_key" {
  value = azurerm_application_insights.ai.instrumentation_key
  sensitive = true
}

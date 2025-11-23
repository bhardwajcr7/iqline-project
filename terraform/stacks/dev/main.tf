locals {
  prefix = var.prefix
  tags = {
    project = "devops-assignment"
    env     = var.env
  }
}

resource "azurerm_resource_group" "main" {
  name     = "${local.prefix}-rg"
  location = var.location
  tags     = local.tags
}

module "acr" {
  source              = "../../modules/acr"
  name                = lower("${local.prefix}acr")
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku                 = "Standard"
  tags                = local.tags
}

module "loganalytics" {
  source              = "../../modules/loganalytics"
  name                = "${local.prefix}-law"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  retention_in_days   = 30
  tags                = local.tags
}

module "appinsights" {
  source              = "../../modules/appinsights"
  name                = "${local.prefix}-ai"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

module "keyvault" {
  source              = "../../modules/keyvault"
  name                = "${local.prefix}-kv"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  secret_name         = "app-insights-key"
  secret_value        = module.appinsights.instrumentation_key
  creator_object_id   = data.azurerm_client_config.current.object_id
  ci_object_id        = var.ci_object_id
  tags                = local.tags
}

module "network" {
  source = "../../modules/network"

  name                = "${local.prefix}-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.vnet_address_space
  
aks_subnet_prefix   = var.aks_subnet_prefix
  tags                = local.tags
}

module "aks" {
  source              = "../../modules/aks"
  name                = "${local.prefix}-aks"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${local.prefix}aks"
  kubernetes_version  = var.kubernetes_version
  log_analytics_workspace_id = module.loganalytics.law_id
  node_vm_size        = "Standard_B2s"
  node_count          = 1
  node_min_count      = 1
  node_max_count      = 3
  node_auto_scaling   = true
  acr_id              = module.acr.acr_id
  ci_object_id        = var.ci_object_id
  subnet_id           = module.network.subnet_id
  tags                = local.tags
}

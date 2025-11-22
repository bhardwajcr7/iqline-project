terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
  required_version = ">= 1.3.0"
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "${var.prefix}-law"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
}

resource "azurerm_application_insights" "ai" {
  name                = "${var.prefix}-ai"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
}

resource "azurerm_container_registry" "acr" {
  name                = lower("${var.prefix}acr")
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku                 = "Standard"
  admin_enabled       = false
}

resource "azurerm_key_vault" "kv" {
  name                = "${var.prefix}-kv"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.prefix}-aks"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "${var.prefix}aks"

  default_node_pool {
    name       = "agentpool"
    vm_size    = "Standard_B2s"
    node_count = 1
    min_count  = 1
    max_count  = 3
    auto_scaling_enabled = true
  }

  identity {
    type = "SystemAssigned"
  }

  depends_on = [azurerm_container_registry.acr]
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

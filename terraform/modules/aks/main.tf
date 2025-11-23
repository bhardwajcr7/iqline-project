resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix

  kubernetes_version = var.kubernetes_version

  default_node_pool {
    name                 = var.node_pool_name
    vm_size              = var.node_vm_size
    node_count           = var.node_count
    min_count            = var.node_min_count
    max_count            = var.node_max_count
    auto_scaling_enabled = var.node_auto_scaling
    vnet_subnet_id       = var.subnet_id
    os_disk_size_gb      = var.node_os_disk_size_gb
    type                 = "VirtualMachineScaleSets"
  }

  identity {
    type = "SystemAssigned"
  }

    oms_agent {
      log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

resource "azurerm_role_assignment" "ci_aks_user" {
  count                = var.ci_object_id == "" ? 0 : 1
  scope                = azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = var.ci_object_id
}

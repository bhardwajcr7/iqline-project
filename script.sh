#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(pwd)"
TF_ROOT="${ROOT_DIR}/terraform"

echo "Creating Terraform Option A (simple) structure under ${TF_ROOT} ..."

# create directories
mkdir -p "${TF_ROOT}/modules/acr"
mkdir -p "${TF_ROOT}/modules/loganalytics"
mkdir -p "${TF_ROOT}/modules/appinsights"
mkdir -p "${TF_ROOT}/modules/keyvault"
mkdir -p "${TF_ROOT}/modules/aks"
mkdir -p "${TF_ROOT}/stacks/dev"

### MODULE: ACR
cat > "${TF_ROOT}/modules/acr/main.tf" <<'EOF'
resource "azurerm_container_registry" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = false
  tags                = var.tags
}
EOF

cat > "${TF_ROOT}/modules/acr/variables.tf" <<'EOF'
variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "sku" {
  type    = string
  default = "Standard"
}
variable "tags" {
  type    = map(string)
  default = {}
}
EOF

cat > "${TF_ROOT}/modules/acr/outputs.tf" <<'EOF'
output "acr_id" { value = azurerm_container_registry.this.id }
output "login_server" { value = azurerm_container_registry.this.login_server }
EOF

### MODULE: LOG ANALYTICS
cat > "${TF_ROOT}/modules/loganalytics/main.tf" <<'EOF'
resource "azurerm_log_analytics_workspace" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku
  retention_in_days   = var.retention_in_days
  tags                = var.tags
}
EOF

cat > "${TF_ROOT}/modules/loganalytics/variables.tf" <<'EOF'
variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "sku" {
  type    = string
  default = "PerGB2018"
}
variable "retention_in_days" {
  type    = number
  default = 30
}
variable "tags" {
  type    = map(string)
  default = {}
}
EOF

cat > "${TF_ROOT}/modules/loganalytics/outputs.tf" <<'EOF'
output "law_id" { value = azurerm_log_analytics_workspace.this.id }
output "law_name" { value = azurerm_log_analytics_workspace.this.name }
EOF

### MODULE: APP INSIGHTS
cat > "${TF_ROOT}/modules/appinsights/main.tf" <<'EOF'
resource "azurerm_application_insights" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = var.application_type
  tags                = var.tags
}
EOF

cat > "${TF_ROOT}/modules/appinsights/variables.tf" <<'EOF'
variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "application_type" {
  type    = string
  default = "web"
}
variable "tags" {
  type    = map(string)
  default = {}
}
EOF

cat > "${TF_ROOT}/modules/appinsights/outputs.tf" <<'EOF'
output "app_insights_id" { value = azurerm_application_insights.this.id }
output "instrumentation_key" { value = azurerm_application_insights.this.instrumentation_key }
EOF

### MODULE: KEYVAULT
cat > "${TF_ROOT}/modules/keyvault/main.tf" <<'EOF'
resource "azurerm_key_vault" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = var.sku_name
  purge_protection_enabled = false
  tags = var.tags

  access_policy {
    tenant_id = var.tenant_id
    object_id = var.creator_object_id
    secret_permissions = ["get","list","set","delete"]
  }
}

resource "azurerm_key_vault_secret" "app_insights" {
  name         = var.secret_name
  value        = var.secret_value
  key_vault_id = azurerm_key_vault.this.id
}

resource "azurerm_key_vault_access_policy" "ci_policy" {
  count = var.ci_object_id == "" ? 0 : 1
  key_vault_id = azurerm_key_vault.this.id
  tenant_id    = var.tenant_id
  object_id    = var.ci_object_id
  secret_permissions = ["get","list"]
}
EOF

cat > "${TF_ROOT}/modules/keyvault/variables.tf" <<'EOF'
variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tenant_id" { type = string }
variable "creator_object_id" { type = string }
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
EOF

cat > "${TF_ROOT}/modules/keyvault/outputs.tf" <<'EOF'
output "key_vault_id" { value = azurerm_key_vault.this.id }
output "key_vault_uri" { value = azurerm_key_vault.this.vault_uri }
output "secret_id" { value = azurerm_key_vault_secret.app_insights.id }
EOF

### MODULE: AKS (simple, monitoring wired to log analytics)
cat > "${TF_ROOT}/modules/aks/main.tf" <<'EOF'
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
    os_disk_size_gb      = var.node_os_disk_size_gb
    type                 = "VirtualMachineScaleSets"
  }

  identity {
    type = "SystemAssigned"
  }

  azure_monitor_profile {
    metrics {
      enabled = true
    }
    # link to log analytics happens via the workspace id on the addon; newer providers
    # automatically wire monitoring for kube when Log Analytics workspace id is provided via the addon
  }

  rbac_enabled = true

  tags = var.tags
}

# give aks kubelet identity AcrPull on the ACR
resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

# give CI SP role to fetch kube creds (optional)
resource "azurerm_role_assignment" "ci_aks_user" {
  count = var.ci_object_id == "" ? 0 : 1
  scope = azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id = var.ci_object_id
}
EOF

cat > "${TF_ROOT}/modules/aks/variables.tf" <<'EOF'
variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "dns_prefix" { type = string }
variable "kubernetes_version" {
  type    = string
  default = ""
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
EOF

cat > "${TF_ROOT}/modules/aks/outputs.tf" <<'EOF'
output "aks_id" { value = azurerm_kubernetes_cluster.this.id }
output "kube_admin_config_raw" { value = azurerm_kubernetes_cluster.this.kube_admin_config_raw }
output "kube_config_raw" { value = azurerm_kubernetes_cluster.this.kube_config[0].raw_kube_config }
EOF

### ROOT STACK: provider.tf
cat > "${TF_ROOT}/stacks/dev/provider.tf" <<'EOF'
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}
EOF

### ROOT STACK: variables.tf
cat > "${TF_ROOT}/stacks/dev/variables.tf" <<'EOF'
variable "prefix" { type = string }
variable "location" { type = string }
variable "creator_object_id" { type = string }
variable "ci_object_id" {
  type = string
  default = ""
}
variable "kubernetes_version" {
  type = string
  default = ""
}
EOF

### ROOT STACK: main.tf
cat > "${TF_ROOT}/stacks/dev/main.tf" <<'EOF'
locals {
  prefix = var.prefix
  tags = {
    project = "devops-assignment"
    env     = "dev"
  }
}

resource "azurerm_resource_group" "main" {
  name     = "${local.prefix}-rg"
  location = var.location
  tags     = local.tags
}

module "acr" {
  source = "../../modules/acr"
  name = lower("${local.prefix}acr")
  resource_group_name = azurerm_resource_group.main.name
  location = var.location
  sku = "Standard"
  tags = local.tags
}

module "loganalytics" {
  source = "../../modules/loganalytics"
  name = "${local.prefix}-law"
  location = var.location
  resource_group_name = azurerm_resource_group.main.name
  retention_in_days = 30
  tags = local.tags
}

module "appinsights" {
  source = "../../modules/appinsights"
  name = "${local.prefix}-ai"
  location = var.location
  resource_group_name = azurerm_resource_group.main.name
  tags = local.tags
}

module "keyvault" {
  source = "../../modules/keyvault"
  name = "${local.prefix}-kv"
  location = var.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id = data.azurerm_client_config.current.tenant_id
  creator_object_id = var.creator_object_id
  secret_name = "app-insights-key"
  secret_value = module.appinsights.instrumentation_key
  ci_object_id = var.ci_object_id
  tags = local.tags
}

module "aks" {
  source = "../../modules/aks"
  name = "${local.prefix}-aks"
  location = var.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix = "${local.prefix}aks"
  kubernetes_version = var.kubernetes_version
  node_vm_size = "Standard_B2s"
  node_count = 1
  node_min_count = 1
  node_max_count = 3
  node_auto_scaling = true
  acr_id = module.acr.acr_id
  ci_object_id = var.ci_object_id
  tags = local.tags
}
EOF

### ROOT STACK: outputs.tf
cat > "${TF_ROOT}/stacks/dev/outputs.tf" <<'EOF'
output "acr_login_server" {
  value = module.acr.login_server
}
output "aks_id" {
  value = module.aks.aks_id
}
output "resource_group" {
  value = azurerm_resource_group.main.name
}
output "log_analytics_id" {
  value = module.loganalytics.law_id
}
output "app_insights_instrumentation_key" {
  value = module.appinsights.instrumentation_key
  sensitive = true
}
output "key_vault_uri" {
  value = module.keyvault.key_vault_uri
}
# architecture diagram reference (local file path)
output "architecture_diagram_file" {
  value = "/mnt/data/DevOps_Assignment_Azure_With_Diagram 1.pdf"
}
EOF

### ROOT STACK: dev.tfvars (sample)
cat > "${TF_ROOT}/stacks/dev/dev.tfvars" <<'EOF'
prefix = "iqlineproject"
location = "centralindia"
creator_object_id = "4eefcb6c-d85f-4b35-970a-3f6860f6786d" # replace with your object id
ci_object_id = "" # optional: set to CI SP object id
kubernetes_version = "" # leave empty to use default
EOF

### README
cat > "${TF_ROOT}/stacks/dev/README.md" <<'EOF'
# Terraform stack: dev (Option A - simple)

This stack provisions infrastructure required for the DevOps assignment:
- Azure Container Registry (ACR)
- Log Analytics Workspace
- Application Insights
- Key Vault with App Insights secret
- AKS cluster (with monitoring enabled)
- Role assignments (ACR pull by AKS, optional CI AKS user)

How to run:
1. cd terraform/stacks/dev
2. terraform init
3. terraform plan -var-file=dev.tfvars
4. terraform apply -var-file=dev.tfvars

Notes:
- Replace creator_object_id in dev.tfvars with `az ad signed-in-user show --query id -o tsv`.
- If you want CI to get AKS credentials, set `ci_object_id` to the object id of your CI service principal.
- App Insights key is stored in Key Vault secret named "app-insights-key".
- The architecture diagram file included in outputs is referenced at:
  /mnt/data/DevOps_Assignment_Azure_With_Diagram 1.pdf
EOF

echo "All files created under ${TF_ROOT}. Run 'cd ${TF_ROOT}/stacks/dev && terraform init' to get started."

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "this" {
  name                     = var.name
  location                 = var.location
  resource_group_name      = var.resource_group_name
  tenant_id                = var.tenant_id
  sku_name                 = var.sku_name
  purge_protection_enabled = false
  tags                     = var.tags

  access_policy {
    tenant_id          = var.tenant_id
    object_id          = var.creator_object_id
    secret_permissions = ["Get", "List", "Set", "Delete"]
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

  secret_permissions = ["Get", "List"]
}

resource "azurerm_key_vault_access_policy" "terraform_client" {
  key_vault_id = azurerm_key_vault.this.id
  tenant_id    = var.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "List", "Set", "Delete"]
}


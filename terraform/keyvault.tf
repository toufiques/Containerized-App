resource "azurerm_key_vault" "main" {
  name                       = "kv-${var.project_name}-${random_string.suffix.result}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  purge_protection_enabled   = false # keep false for a lab so you can delete/recreate freely
  soft_delete_retention_days = 7
}

# Give yourself (the identity running this apply) rights to manage secrets.
resource "azurerm_role_assignment" "kv_admin_me" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# A sample secret, just so you have something to practice referencing from
# the AKS Key Vault CSI driver / az cli in a later exercise.
resource "azurerm_key_vault_secret" "sample" {
  name         = "sample-secret"
  value        = "ChangeMe123!"
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.kv_admin_me]
}

resource "azurerm_container_registry" "main" {
  name                = "acr${var.project_name}${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = false # we push/pull via Entra ID identities, not admin keys
}

resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

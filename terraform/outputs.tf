output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "acr_name" {
  value = azurerm_container_registry.main.name
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "aks_admins_group_object_id" {
  value = azuread_group.aks_admins.object_id
}

output "github_actions_client_id" {
  description = "Set this as the AZURE_CLIENT_ID secret in your GitHub repo"
  value       = azuread_application.github_actions.client_id
}

output "tenant_id" {
  description = "Set this as the AZURE_TENANT_ID secret in your GitHub repo"
  value       = data.azurerm_client_config.current.tenant_id
}

output "subscription_id" {
  description = "Set this as the AZURE_SUBSCRIPTION_ID secret in your GitHub repo"
  value       = data.azurerm_client_config.current.subscription_id
}

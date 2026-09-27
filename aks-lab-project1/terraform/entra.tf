data "azuread_client_config" "current" {}

data "azuread_user" "me" {
  user_principal_name = var.admin_upn
}

# --- Cluster admin group (you) ---------------------------------------------

resource "azuread_group" "aks_admins" {
  display_name     = "${var.project_name}-aks-admins"
  security_enabled = true
  owners           = [data.azuread_client_config.current.object_id]
  members          = [data.azuread_user.me.object_id]
}

resource "azurerm_role_assignment" "aks_admins_cluster_admin" {
  scope                = azurerm_kubernetes_cluster.main.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = azuread_group.aks_admins.object_id
}

# --- GitHub Actions OIDC identity (no stored secrets) -----------------------

resource "azuread_application" "github_actions" {
  display_name = "${var.project_name}-github-actions"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "github_actions" {
  client_id = azuread_application.github_actions.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_federated_identity_credential" "github_main" {
  application_id = azuread_application.github_actions.id
  display_name   = "github-${var.github_branch}"
  description    = "Trust GitHub Actions on the ${var.github_branch} branch"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_org}/${var.github_repo_name}:ref:refs/heads/${var.github_branch}"
}

# So plan/apply also works from pull_request-triggered workflow runs.
resource "azuread_application_federated_identity_credential" "github_pr" {
  application_id = azuread_application.github_actions.id
  display_name   = "github-pull-request"
  description    = "Trust GitHub Actions on pull_request events"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_org}/${var.github_repo_name}:pull_request"
}

# Let CI manage infra (create/update/destroy resources in this RG).
resource "azurerm_role_assignment" "github_actions_contributor" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.github_actions.object_id
}

# Let CI push built images to ACR.
resource "azurerm_role_assignment" "github_actions_acr_push" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPush"
  principal_id         = azuread_service_principal.github_actions.object_id
}

# Let CI fetch a kubeconfig context (control-plane level, not data-plane RBAC).
resource "azurerm_role_assignment" "github_actions_cluster_user" {
  scope                = azurerm_kubernetes_cluster.main.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azuread_service_principal.github_actions.object_id
}

# Let CI actually deploy workloads, deliberately narrower than full admin.
resource "azurerm_role_assignment" "github_actions_rbac_writer" {
  scope                = azurerm_kubernetes_cluster.main.id
  role_definition_name = "Azure Kubernetes Service RBAC Writer"
  principal_id         = azuread_service_principal.github_actions.object_id
}

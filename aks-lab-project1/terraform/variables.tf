variable "project_name" {
  description = "Short name used as a prefix for all resources"
  type        = string
  default     = "akslab"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "my_ip_cidr" {
  description = "Your public IP in CIDR form, e.g. 203.0.113.10/32 - used to lock down NSG and AKS API server access"
  type        = string
}

variable "admin_upn" {
  description = "Your Entra ID user principal name (UPN), e.g. you@yourtenant.onmicrosoft.com - added as AKS cluster admin"
  type        = string
}

variable "github_org" {
  description = "Your GitHub username or org that owns the repo"
  type        = string
}

variable "github_repo_name" {
  description = "The GitHub repository name (without org prefix)"
  type        = string
}

variable "github_branch" {
  description = "Branch GitHub Actions will authenticate from via OIDC"
  type        = string
  default     = "main"
}

variable "node_count" {
  description = "Number of AKS nodes"
  type        = number
  default     = 2
}

variable "node_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_B2ms"
}

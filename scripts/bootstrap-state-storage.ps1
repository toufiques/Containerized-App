# One-time bootstrap script for Terraform remote state storage (Windows/PowerShell).
# Run this ONCE, before any terraform init/apply, using your own `az login`.
# It creates the storage account Terraform will use to store its state file.
# This can't live inside Terraform itself - Terraform needs somewhere to
# write state before it exists.

$ErrorActionPreference = "Stop"

$Location      = "eastus"
$RgName        = "rg-tfstate-akslab"
$ContainerName = "tfstate"
$Suffix        = -join ((48..57) + (97..102) | Get-Random -Count 6 | ForEach-Object { [char]$_ })
$SaName        = "sttfstateakslab$Suffix"

Write-Host "Creating resource group: $RgName"
az group create --name $RgName --location $Location -o none

Write-Host "Creating storage account: $SaName"
az storage account create `
  --name $SaName `
  --resource-group $RgName `
  --location $Location `
  --sku Standard_LRS `
  --encryption-services blob `
  --min-tls-version TLS1_2 `
  --allow-blob-public-access false `
  -o none

Write-Host "Creating blob container: $ContainerName"
az storage container create `
  --name $ContainerName `
  --account-name $SaName `
  --auth-mode login `
  -o none

Write-Host ""
Write-Host "Done. Now create terraform/backend.hcl with:"
Write-Host ""
Write-Host "resource_group_name  = `"$RgName`""
Write-Host "storage_account_name = `"$SaName`""
Write-Host "container_name       = `"$ContainerName`""
Write-Host "key                  = `"project1.terraform.tfstate`""
Write-Host ""

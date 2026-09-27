#!/usr/bin/env bash
# Run this ONCE, before any terraform init/apply, using your own `az login`.
# It creates the storage account Terraform will use to store its state file.
# This can't live inside Terraform itself - Terraform needs somewhere to
# write state before it exists.

set -euo pipefail

LOCATION="eastus"
RG_NAME="rg-tfstate-akslab"
CONTAINER_NAME="tfstate"
SUFFIX=$(openssl rand -hex 3)
SA_NAME="sttfstateakslab${SUFFIX}"

echo "Creating resource group: $RG_NAME"
az group create --name "$RG_NAME" --location "$LOCATION" -o none

echo "Creating storage account: $SA_NAME"
az storage account create \
  --name "$SA_NAME" \
  --resource-group "$RG_NAME" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --encryption-services blob \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  -o none

echo "Creating blob container: $CONTAINER_NAME"
az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$SA_NAME" \
  --auth-mode login \
  -o none

cat <<EOF

Done. Now create terraform/backend.hcl with:

resource_group_name  = "$RG_NAME"
storage_account_name = "$SA_NAME"
container_name       = "$CONTAINER_NAME"
key                  = "project1.terraform.tfstate"

EOF

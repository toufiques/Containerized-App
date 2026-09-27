# AKS Lab — Project 1

Minimal but complete hands-on lab: Terraform-provisioned AKS cluster, GitHub
Actions CI/CD (OIDC, no stored secrets), Entra ID-based access control,
and Prometheus/Grafana monitoring.

## What gets created

- Resource Group, VNet/Subnet, NSG (Azure)
- Azure Container Registry (Basic)
- AKS cluster (2 nodes, Entra ID auth only, Azure RBAC for Kubernetes, API
  server locked to your IP)
- Key Vault (RBAC-authorized)
- Entra ID: a security group for cluster admins (you) + an App Registration
  with a federated credential for GitHub Actions (passwordless OIDC)

## Prerequisites (install once)

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.7
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)
- Docker Desktop (or another local Docker engine)
- VS Code extensions: **HashiCorp Terraform**, **Kubernetes**, **Azure
  Account**

You'll need a role in your Entra ID tenant that can create App
Registrations and Groups (Application Administrator / Groups Administrator,
or Global Admin). If this is your own personal Azure/M365 tenant, you
already have this.

---

## Sequence — follow in this exact order

### 1. Clone this repo locally and open it in VS Code

```bash
git clone <your-new-empty-github-repo-url>
# copy all files from this scaffold into that folder, or
# init this folder as the repo (see step 8)
code .
```

### 2. Log in to Azure

```bash
az login
az account show   # confirm the right subscription is selected
```

### 3. Bootstrap the Terraform state storage (one-time, run locally)

Terraform needs somewhere to store its state *before* Terraform itself can
create anything — this can't be a Terraform resource.

```bash
chmod +x scripts/bootstrap-state-storage.sh
./scripts/bootstrap-state-storage.sh
```

Copy the output values into a new file `terraform/backend.hcl` (copy from
`terraform/backend.hcl.example` as a template). This file is gitignored —
it's local-only.

### 4. Fill in your variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
- `my_ip_cidr` — run `curl -4 ifconfig.me` and append `/32`
- `admin_upn` — your Entra ID sign-in email
- `github_org` / `github_repo_name` — the GitHub repo you'll push this to

This file is gitignored too (it has no secrets, but keeps your personal IP
out of git history).

### 5. Format and initialize Terraform

```bash
terraform fmt -recursive
terraform init -backend-config=backend.hcl
```

### 6. Plan, then apply — using YOUR Azure login

This first apply must run under your own `az login` session, because it's
what *creates* the GitHub Actions identity that CI will use afterward.

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

This takes 10–15 minutes (AKS provisioning is the slow part). Grab coffee.

### 7. Capture the outputs you'll need for GitHub

```bash
terraform output
```

Note down: `github_actions_client_id`, `tenant_id`, `subscription_id`,
`resource_group_name`, `acr_name`, `aks_cluster_name`.

### 8. Push the repo to GitHub

```bash
cd ..
git init   # if not already a repo
git add .
git commit -m "Initial AKS lab scaffold"
git branch -M main
git remote add origin <your-empty-github-repo-url>
git push -u origin main
```

> ⚠️ Pushing `terraform/**` will trigger `terraform.yml` immediately. It
> will fail at the Azure login step until you complete step 9 — that's
> expected, not a problem.

### 9. Configure GitHub repo secrets and variables

In your GitHub repo → **Settings → Secrets and variables → Actions**:

**Secrets** (sensitive):
| Name | Value |
|---|---|
| `AZURE_CLIENT_ID` | `github_actions_client_id` output |
| `AZURE_TENANT_ID` | `tenant_id` output |
| `AZURE_SUBSCRIPTION_ID` | `subscription_id` output |

**Variables** (not sensitive):
| Name | Value |
|---|---|
| `RESOURCE_GROUP` | `resource_group_name` output |
| `ACR_NAME` | `acr_name` output |
| `AKS_CLUSTER_NAME` | `aks_cluster_name` output |
| `TFSTATE_RG` | `rg-tfstate-akslab` (from step 3) |
| `TFSTATE_SA` | the storage account name printed in step 3 |
| `TFSTATE_CONTAINER` | `tfstate` |

Re-run the failed `terraform.yml` workflow from the Actions tab once these
are set — it should now pass `plan` cleanly (it only `apply`s on pushes to
`main`, which already happened, so it'll apply too — harmless, since
nothing changed).

### 10. Verify kubectl access with your own Entra identity

```bash
az aks get-credentials --resource-group <resource_group_name> --name <aks_cluster_name>
kubectl get nodes
```

This triggers an interactive Entra ID device-code login the first time
(cluster has no local accounts) — sign in with the same account as
`admin_upn`. You should see 2 nodes `Ready`.

### 11. Trigger the app deployment

Any push touching `app/**` or `k8s/**` fires `app-deploy.yml`. Make a
trivial change to force the first run:

```bash
echo "# v1" >> app/app.py
git add app/app.py
git commit -m "Trigger first app deploy"
git push
```

Watch it in the GitHub Actions tab. Once it completes:

```bash
kubectl get svc aks-lab-app
# wait for EXTERNAL-IP to populate, then:
curl http://<EXTERNAL-IP>/
```

You should get back JSON with a hostname and pod name.

### 12. Install monitoring (Prometheus + Grafana)

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace
```

Access Grafana:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

Open http://localhost:3000 — default user `admin`, password:

```bash
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d
```

Browse the built-in dashboards under **Dashboards** — node CPU/memory,
Kubernetes / Compute Resources, etc.

---

## Sanity checks if something breaks

| Symptom | Likely cause |
|---|---|
| `terraform apply` fails with 403 creating the App Registration | Your Entra role lacks Application Administrator — check tenant role assignments |
| GitHub Action fails at `azure/login` with AADSTS70021 | Federated credential `subject` doesn't match your repo/branch exactly — check `github_org`/`github_repo_name` in tfvars |
| `kubectl get nodes` hangs or times out | Your public IP changed since `terraform apply` — update `my_ip_cidr` and re-apply, or re-run `curl -4 ifconfig.me` |
| ACR push fails with 401 in CI | `AcrPush` role assignment didn't propagate yet — Entra role assignments can take a couple of minutes; re-run the job |

## Cleanup (avoid ongoing cost)

```bash
cd terraform
terraform destroy
```

Then manually delete the state storage resource group (not managed by
Terraform):

```bash
az group delete --name rg-tfstate-akslab --yes --no-wait
```

Also delete the App Registration if `terraform destroy` doesn't remove it
cleanly:

```bash
az ad app delete --id <github_actions_client_id>
```

---

## What's deliberately left out of v1

- Ingress controller, TLS, your GoDaddy domain → Project 2
- Pulumi (re-implementing this same stack for comparison) → Project 2/3
- Jenkins as an alternative to GitHub Actions → later project
- Namespace-scoped RBAC, alerting rules, custom Grafana dashboards

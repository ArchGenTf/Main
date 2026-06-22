# ArchGen Infrastructure — Secrets & Configuration Reference

This document is a complete reference for **every secret that must be provisioned in Azure Key Vault** and **every placeholder that must be updated** in the Helm charts and raw Kubernetes manifests before deploying to either the `dev` or `prod` environment.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Azure Key Vault Secrets](#2-azure-key-vault-secrets)
   - [dev Key Vault: `kv-archgen-dev`](#21-dev-key-vault-kv-archgen-dev)
   - [prod Key Vault: `kv-archgen-prod`](#22-prod-key-vault-kv-archgen-prod)
3. [Helm Chart Configuration Changes](#3-helm-chart-configuration-changes)
   - [auth-service](#31-auth-service)
   - [architecture-service](#32-architecture-service)
   - [project-service](#33-project-service)
   - [api-gateway](#34-api-gateway)
   - [frontend](#35-frontend)
4. [Raw Manifest Configuration Changes](#4-raw-manifest-configuration-changes)
   - [SecretProviderClass manifests (all services)](#41-secretproviderclass-manifests)
   - [ServiceAccount manifests (all services with Key Vault)](#42-serviceaccount-manifests)
5. [GitHub Actions Repository Secrets](#5-github-actions-repository-secrets)
6. [Azure Workload Identity Setup](#6-azure-workload-identity-setup)
7. [Quick Reference Tables](#7-quick-reference-tables)

---

## 1. Architecture Overview

Secrets are injected into pods via the **Secrets Store CSI Driver** using **Azure Workload Identity** (not pod identity or VM managed identity). The flow is:

```
Azure Key Vault
      │
      │ (Workload Identity via OIDC)
      ▼
SecretProviderClass (per service)
      │
      │ (CSI volume mount)
      ▼
Pod (/mnt/secrets-store/<alias>)
```

Three services use Key Vault integration:
- **auth-service** — JWT signing secret
- **architecture-service** — AI provider API keys
- **project-service** — Cosmos DB connection string

Two services do **NOT** use Key Vault (no secrets needed at runtime):
- **api-gateway** — acts as reverse proxy only
- **frontend** — static React/Next.js build, no server-side secrets

---

## 2. Azure Key Vault Secrets

### 2.1 dev Key Vault: `kv-archgen-dev`

Create the following secrets in the `kv-archgen-dev` Key Vault instance:

| Secret Name (Key Vault) | Env Alias (in pod) | Used By | Description |
|---|---|---|---|
| `jwt-secret` | `JWT_SECRET` | auth-service | HS256/RS256 signing key used to sign and verify JWTs. Must be a strong random string (≥ 32 chars). |
| `openai-api-key` | `OPENAI_API_KEY` | architecture-service | OpenAI API key from [platform.openai.com](https://platform.openai.com/api-keys). |
| `deepseek-api-key` | `DEEPSEEK_API_KEY` | architecture-service | DeepSeek API key from [platform.deepseek.com](https://platform.deepseek.com/). |
| `cosmos-connection-string` | `COSMOS_CONNECTION_STRING` | project-service | Azure Cosmos DB primary connection string (from Azure Portal → Cosmos DB → Keys). |

#### How to add secrets via Azure CLI

```bash
# Log in
az login
az keyvault set-secret --vault-name "kv-archgen-dev" --name "jwt-secret" --value "YOUR_STRONG_JWT_SECRET"
az keyvault set-secret --vault-name "kv-archgen-dev" --name "openai-api-key" --value "sk-..."
az keyvault set-secret --vault-name "kv-archgen-dev" --name "deepseek-api-key" --value "sk-..."
az keyvault set-secret --vault-name "kv-archgen-dev" --name "cosmos-connection-string" --value "AccountEndpoint=https://..."
```

---

### 2.2 prod Key Vault: `kv-archgen-prod`

Create the **same secret names** in `kv-archgen-prod` with production values:

| Secret Name (Key Vault) | Env Alias (in pod) | Used By | Description |
|---|---|---|---|
| `jwt-secret` | `JWT_SECRET` | auth-service | **Different, stronger** secret than dev. Rotate periodically. |
| `openai-api-key` | `OPENAI_API_KEY` | architecture-service | Production OpenAI API key (separate from dev key for billing/auditing). |
| `deepseek-api-key` | `DEEPSEEK_API_KEY` | architecture-service | Production DeepSeek API key. |
| `cosmos-connection-string` | `COSMOS_CONNECTION_STRING` | project-service | Production Cosmos DB connection string (different account than dev). |

```bash
az keyvault set-secret --vault-name "kv-archgen-prod" --name "jwt-secret" --value "YOUR_PROD_JWT_SECRET"
az keyvault set-secret --vault-name "kv-archgen-prod" --name "openai-api-key" --value "sk-..."
az keyvault set-secret --vault-name "kv-archgen-prod" --name "deepseek-api-key" --value "sk-..."
az keyvault set-secret --vault-name "kv-archgen-prod" --name "cosmos-connection-string" --value "AccountEndpoint=https://..."
```

---

## 3. Helm Chart Configuration Changes

All Helm `values-dev.yaml` and `values-prod.yaml` files contain placeholder values of `00000000-0000-0000-0000-000000000000` for the Azure identity fields. These **must be replaced** before deploying.

### 3.1 auth-service

**Files:**
- [`k8s/auth-service/values-dev.yaml`](k8s/auth-service/values-dev.yaml)
- [`k8s/auth-service/values-prod.yaml`](k8s/auth-service/values-prod.yaml)

**Changes required:**

```yaml
# BEFORE (placeholder)
keyvault:
  enabled: true
  name: "kv-archgen-dev"                         # ✅ Correct — do not change
  clientId: "00000000-0000-0000-0000-000000000000"  # ❌ Replace with real value
  tenantId: "00000000-0000-0000-0000-000000000000"  # ❌ Replace with real value

# AFTER (example)
keyvault:
  enabled: true
  name: "kv-archgen-dev"
  clientId: "<MANAGED_IDENTITY_CLIENT_ID>"   # Client ID of the User-Assigned Managed Identity
  tenantId: "<AZURE_TENANT_ID>"              # Your Azure AD Tenant ID
```

| Field | How to get the value |
|---|---|
| `clientId` | Azure Portal → Managed Identities → `<identity-name>` → Client ID. Or: `az identity show --name <identity> --resource-group <rg> --query clientId -o tsv` |
| `tenantId` | Azure Portal → Azure Active Directory → Overview → Tenant ID. Or: `az account show --query tenantId -o tsv` |

---

### 3.2 architecture-service

**Files:**
- [`k8s/architecture-service/values-dev.yaml`](k8s/architecture-service/values-dev.yaml)
- [`k8s/architecture-service/values-prod.yaml`](k8s/architecture-service/values-prod.yaml)

**Changes required** (same pattern as auth-service):

```yaml
keyvault:
  enabled: true
  name: "kv-archgen-dev"                            # ✅ Correct
  clientId: "00000000-0000-0000-0000-000000000000"  # ❌ Replace with Managed Identity Client ID
  tenantId: "00000000-0000-0000-0000-000000000000"  # ❌ Replace with Azure Tenant ID
  secrets:
    - name: "openai-api-key"      # ✅ Must match Key Vault secret name exactly
      alias: "OPENAI_API_KEY"     # ✅ This becomes the env var / file name in /mnt/secrets-store/
    - name: "deepseek-api-key"
      alias: "DEEPSEEK_API_KEY"
```

---

### 3.3 project-service

**Files:**
- [`k8s/project-service/values-dev.yaml`](k8s/project-service/values-dev.yaml)
- [`k8s/project-service/values-prod.yaml`](k8s/project-service/values-prod.yaml)

```yaml
keyvault:
  enabled: true
  name: "kv-archgen-dev"                            # ✅ Correct
  clientId: "00000000-0000-0000-0000-000000000000"  # ❌ Replace with Managed Identity Client ID
  tenantId: "00000000-0000-0000-0000-000000000000"  # ❌ Replace with Azure Tenant ID
  secrets:
    - name: "cosmos-connection-string"  # ✅ Must match Key Vault secret name exactly
      alias: "COSMOS_CONNECTION_STRING"
```

---

### 3.4 api-gateway

**Files:**
- [`k8s/api-gateway/values-dev.yaml`](k8s/api-gateway/values-dev.yaml)
- [`k8s/api-gateway/values-prod.yaml`](k8s/api-gateway/values-prod.yaml)

> [!NOTE]
> The api-gateway has **no Key Vault integration** — no secrets are needed. However, the following fields should still be verified:

| Field | Current dev value | Current prod value | Action |
|---|---|---|---|
| `ingress.hosts[0].host` | `api-dev.archgen.com` | `api.archgen.com` | ✅ Update to your real domain if different |
| `image.repository` | `acrarchgen.azurecr.io/api-gateway` | same | ✅ Verify ACR name matches your actual ACR |
| `image.tag` | `"latest"` | `"latest"` | ⚠️ Managed by GitOps pipeline; leave as-is |

---

### 3.5 frontend

**Files:**
- [`k8s/frontend/values-dev.yaml`](k8s/frontend/values-dev.yaml)
- [`k8s/frontend/values-prod.yaml`](k8s/frontend/values-prod.yaml)

> [!NOTE]
> The frontend has **no Key Vault integration**. Verify the following:

| Field | Current dev value | Current prod value | Action |
|---|---|---|---|
| `ingress.hosts[0].host` | `dev.archgen.com` | `frontend.archgen.com` | ✅ Update to your real domain |
| `image.repository` | `acrarchgen.azurecr.io/frontend` | same | ✅ Verify ACR name |
| `image.tag` | `"sha-c74a815"` (dev) | `"latest"` (prod) | ⚠️ Managed by GitOps; leave as-is |

---

## 4. Raw Manifest Configuration Changes

The raw manifests under `manifests/dev/` and `manifests/prod/` are the GitOps-applied Kubernetes YAML files. They contain the same placeholder values.

### 4.1 SecretProviderClass Manifests

All `*-secrets-provider.yaml` files have two placeholder values that must be updated:

#### Files to update

| Environment | File | Service |
|---|---|---|
| dev | [`manifests/dev/auth-service-secrets-provider.yaml`](manifests/dev/auth-service-secrets-provider.yaml) | auth-service |
| dev | [`manifests/dev/architecture-service-secrets-provider.yaml`](manifests/dev/architecture-service-secrets-provider.yaml) | architecture-service |
| dev | [`manifests/dev/project-service-secrets-provider.yaml`](manifests/dev/project-service-secrets-provider.yaml) | project-service |
| prod | [`manifests/prod/auth-service-secrets-provider.yaml`](manifests/prod/auth-service-secrets-provider.yaml) | auth-service |
| prod | [`manifests/prod/architecture-service-secrets-provider.yaml`](manifests/prod/architecture-service-secrets-provider.yaml) | architecture-service |
| prod | [`manifests/prod/project-service-secrets-provider.yaml`](manifests/prod/project-service-secrets-provider.yaml) | project-service |

#### What to change in each file

```yaml
# BEFORE
parameters:
  clientID: "00000000-0000-0000-0000-000000000000"  # ❌ Placeholder
  keyvaultName: "kv-archgen-dev"                     # ✅ Correct
  tenantId: "00000000-0000-0000-0000-000000000000"  # ❌ Placeholder

# AFTER
parameters:
  clientID: "<MANAGED_IDENTITY_CLIENT_ID>"   # ❌ Replace — User-Assigned Managed Identity Client ID
  keyvaultName: "kv-archgen-dev"             # ✅ Leave as-is
  tenantId: "<AZURE_TENANT_ID>"              # ❌ Replace — Your Azure AD Tenant ID
```

> [!IMPORTANT]
> The `clientID` in the `SecretProviderClass` and the `azure.workload.identity/client-id` annotation on the `ServiceAccount` **must match** each other. Both must be the **Client ID** of the same User-Assigned Managed Identity that has been granted `Key Vault Secrets User` role on the Key Vault.

---

### 4.2 ServiceAccount Manifests

#### Files to update

| Environment | File | Service |
|---|---|---|
| dev | [`manifests/dev/auth-service-serviceaccount.yaml`](manifests/dev/auth-service-serviceaccount.yaml) | auth-service |
| dev | [`manifests/dev/architecture-service-serviceaccount.yaml`](manifests/dev/architecture-service-serviceaccount.yaml) | architecture-service |
| dev | [`manifests/dev/project-service-serviceaccount.yaml`](manifests/dev/project-service-serviceaccount.yaml) | project-service |
| prod | [`manifests/prod/auth-service-serviceaccount.yaml`](manifests/prod/auth-service-serviceaccount.yaml) | auth-service |
| prod | [`manifests/prod/architecture-service-serviceaccount.yaml`](manifests/prod/architecture-service-serviceaccount.yaml) | architecture-service |
| prod | [`manifests/prod/project-service-serviceaccount.yaml`](manifests/prod/project-service-serviceaccount.yaml) | project-service |

#### What to change in each file

```yaml
# BEFORE
metadata:
  annotations:
    azure.workload.identity/client-id: "00000000-0000-0000-0000-000000000000"  # ❌ Placeholder

# AFTER
metadata:
  annotations:
    azure.workload.identity/client-id: "<MANAGED_IDENTITY_CLIENT_ID>"  # ❌ Replace
```

---

### 4.3 Deployment Image Tags

The deployment manifests reference specific ACR instances. Verify the following:

| Environment | Service | Current image value | Action |
|---|---|---|---|
| dev | api-gateway | `acrarchgendev.azurecr.io/api-gateway:latest` | ✅ Confirm your dev ACR name |
| dev | auth-service | `acrarchgendev.azurecr.io/auth-service:latest` | ✅ Confirm your dev ACR name |
| dev | project-service | `acrarchgendev.azurecr.io/project-service:latest` | ✅ Confirm your dev ACR name |
| dev | architecture-service | `acrarchgendev.azurecr.io/architecture-service:latest` | ✅ Confirm your dev ACR name |
| dev | frontend | `acrarchgendev.azurecr.io/frontend:latest` | ✅ Confirm your dev ACR name |
| prod | all | `acrarchgen.azurecr.io/<service>:latest` | ✅ Confirm your prod ACR name |

> [!NOTE]
> In dev manifests, the ACR name is `acrarchgendev`, but the Helm values reference `acrarchgen`. Make sure both are consistent with your actual ACR resource name in Azure.

---

## 5. GitHub Actions Repository Secrets

Configure these in **each microservice repository** (`Settings → Secrets and variables → Actions → New repository secret`):

| Secret Name | Required | Description | How to get |
|---|---|---|---|
| `GH_PAT` | **Required** | GitHub Personal Access Token to dispatch events to the Main Infra repo | GitHub → Settings → Developer Settings → Tokens (Classic) → `repo` scope |
| `AZURE_CREDENTIALS` | **Required** | Azure Service Principal JSON for ACR login and image push | `az ad sp create-for-rbac --name "github-actions-sp" --role contributor --scopes /subscriptions/<ID>/resourceGroups/<RG> --sdk-auth` |
| `SONAR_TOKEN` | Optional | SonarCloud API token for static code analysis | SonarCloud → My Account → Security → Generate Token |
| `SONAR_KEY` | Optional | Custom SonarCloud project key (defaults to `ArchGenTf_<service>`) | SonarCloud project settings |
| `SNYK_TOKEN` | Optional | Snyk API token for dependency vulnerability scanning | Snyk → Account Settings → Auth Token |
| `SLACK_WEBHOOK` | Optional | Slack Incoming Webhook URL for build notifications | Slack API → Create App → Incoming Webhooks |

> [!IMPORTANT]
> The `GH_PAT` token must have `repo` scope (classic token) or `Contents: Write` + `Metadata: Read` scopes (fine-grained token) on the `ArchGenTf/Main` repository. Without this, the `repository_dispatch` step will fail with a `Bad credentials` error.

---

## 6. Azure Workload Identity Setup

The Secrets Store CSI driver uses Azure Workload Identity. Complete the following setup **before** deploying the manifests:

### Step 1 — Enable OIDC Issuer on AKS

```bash
az aks update \
  --resource-group <RESOURCE_GROUP> \
  --name <AKS_CLUSTER_NAME> \
  --enable-oidc-issuer \
  --enable-workload-identity
```

### Step 2 — Create User-Assigned Managed Identities

Create a separate identity per service (or one shared identity if preferred):

```bash
# Example for auth-service in dev
az identity create \
  --name "id-auth-service-dev" \
  --resource-group <RESOURCE_GROUP> \
  --location <LOCATION>

# Get the Client ID (paste into values-dev.yaml and secrets-provider.yaml)
az identity show \
  --name "id-auth-service-dev" \
  --resource-group <RESOURCE_GROUP> \
  --query clientId -o tsv
```

### Step 3 — Grant Key Vault Access

```bash
# Get the identity's object ID
IDENTITY_OBJECT_ID=$(az identity show \
  --name "id-auth-service-dev" \
  --resource-group <RESOURCE_GROUP> \
  --query principalId -o tsv)

# Assign Key Vault Secrets User role
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee-object-id $IDENTITY_OBJECT_ID \
  --scope /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>/providers/Microsoft.KeyVault/vaults/kv-archgen-dev
```

### Step 4 — Create Federated Identity Credential

Link the managed identity to the Kubernetes ServiceAccount:

```bash
# Get AKS OIDC issuer URL
OIDC_ISSUER=$(az aks show \
  --name <AKS_CLUSTER_NAME> \
  --resource-group <RESOURCE_GROUP> \
  --query "oidcIssuerProfile.issuerUrl" -o tsv)

# Create federated credential for dev namespace
az identity federated-credential create \
  --name "auth-service-dev-federated" \
  --identity-name "id-auth-service-dev" \
  --resource-group <RESOURCE_GROUP> \
  --issuer $OIDC_ISSUER \
  --subject "system:serviceaccount:<NAMESPACE>:archgen-dev-auth-service-sa" \
  --audiences "api://AzureADTokenExchange"
```

> [!IMPORTANT]
> The `--subject` value **must exactly match** `system:serviceaccount:<namespace>:<serviceaccount-name>`. The ServiceAccount name in the manifests is `archgen-dev-auth-service-sa` (dev) and `archgen-prod-auth-service-sa` (prod). The namespace must match where you deploy the pods.

### Step 5 — Install Secrets Store CSI Driver

```bash
helm repo add csi-secrets-store-provider-azure \
  https://azure.github.io/secrets-store-csi-driver-provider-azure/charts

helm install csi-secrets-store-provider-azure \
  csi-secrets-store-provider-azure/csi-secrets-store-provider-azure \
  --namespace kube-system \
  --set secrets-store-csi-driver.enableSecretRotation=true
```

---

## 7. Quick Reference Tables

### Key Vault Secrets Summary

| Key Vault Secret Name | Env Alias | Service | Dev KV | Prod KV |
|---|---|---|---|---|
| `jwt-secret` | `JWT_SECRET` | auth-service | `kv-archgen-dev` | `kv-archgen-prod` |
| `openai-api-key` | `OPENAI_API_KEY` | architecture-service | `kv-archgen-dev` | `kv-archgen-prod` |
| `deepseek-api-key` | `DEEPSEEK_API_KEY` | architecture-service | `kv-archgen-dev` | `kv-archgen-prod` |
| `cosmos-connection-string` | `COSMOS_CONNECTION_STRING` | project-service | `kv-archgen-dev` | `kv-archgen-prod` |

### All Placeholder Values — What to Replace

| Placeholder | Replace With | Appears In |
|---|---|---|
| `00000000-0000-0000-0000-000000000000` (clientId) | Managed Identity Client ID | All `values-*.yaml`, all `*-secrets-provider.yaml`, all `*-serviceaccount.yaml` |
| `00000000-0000-0000-0000-000000000000` (tenantId) | Azure AD Tenant ID | All `values-*.yaml`, all `*-secrets-provider.yaml` |
| `acrarchgendev.azurecr.io` | Your actual dev ACR login server | All `manifests/dev/*-deployment.yaml` |
| `acrarchgen.azurecr.io` | Your actual prod ACR login server | All `manifests/prod/*-deployment.yaml` and Helm values |
| `api-dev.archgen.com` | Your actual dev API domain | `manifests/dev/api-gateway-ingress.yaml`, `k8s/api-gateway/values-dev.yaml` |
| `api.archgen.com` | Your actual prod API domain | `manifests/prod/api-gateway-ingress.yaml`, `k8s/api-gateway/values-prod.yaml` |
| `dev.archgen.com` | Your actual dev frontend domain | `manifests/dev/frontend-ingress.yaml`, `k8s/frontend/values-dev.yaml` |
| `frontend.archgen.com` | Your actual prod frontend domain | `manifests/prod/frontend-ingress.yaml`, `k8s/frontend/values-prod.yaml` |

### Files That Need Changes — Checklist

#### Helm values (for Helm-based deploy)
- [ ] `k8s/auth-service/values-dev.yaml` — `clientId`, `tenantId`
- [ ] `k8s/auth-service/values-prod.yaml` — `clientId`, `tenantId`
- [ ] `k8s/architecture-service/values-dev.yaml` — `clientId`, `tenantId`
- [ ] `k8s/architecture-service/values-prod.yaml` — `clientId`, `tenantId`
- [ ] `k8s/project-service/values-dev.yaml` — `clientId`, `tenantId`
- [ ] `k8s/project-service/values-prod.yaml` — `clientId`, `tenantId`
- [ ] `k8s/api-gateway/values-dev.yaml` — verify hostname
- [ ] `k8s/api-gateway/values-prod.yaml` — verify hostname
- [ ] `k8s/frontend/values-dev.yaml` — verify hostname
- [ ] `k8s/frontend/values-prod.yaml` — verify hostname

#### Raw manifests (for GitOps/kubectl apply)
- [ ] `manifests/dev/auth-service-secrets-provider.yaml` — `clientID`, `tenantId`
- [ ] `manifests/dev/auth-service-serviceaccount.yaml` — `azure.workload.identity/client-id`
- [ ] `manifests/dev/architecture-service-secrets-provider.yaml` — `clientID`, `tenantId`
- [ ] `manifests/dev/architecture-service-serviceaccount.yaml` — `azure.workload.identity/client-id`
- [ ] `manifests/dev/project-service-secrets-provider.yaml` — `clientID`, `tenantId`
- [ ] `manifests/dev/project-service-serviceaccount.yaml` — `azure.workload.identity/client-id`
- [ ] `manifests/prod/auth-service-secrets-provider.yaml` — `clientID`, `tenantId`
- [ ] `manifests/prod/auth-service-serviceaccount.yaml` — `azure.workload.identity/client-id`
- [ ] `manifests/prod/architecture-service-secrets-provider.yaml` — `clientID`, `tenantId`
- [ ] `manifests/prod/architecture-service-serviceaccount.yaml` — `azure.workload.identity/client-id`
- [ ] `manifests/prod/project-service-secrets-provider.yaml` — `clientID`, `tenantId`
- [ ] `manifests/prod/project-service-serviceaccount.yaml` — `azure.workload.identity/client-id`

#### GitHub Actions secrets (per microservice repo)
- [ ] `GH_PAT` — GitHub Personal Access Token
- [ ] `AZURE_CREDENTIALS` — Azure Service Principal JSON
- [ ] `SONAR_TOKEN` — (optional) SonarCloud token
- [ ] `SNYK_TOKEN` — (optional) Snyk token
- [ ] `SLACK_WEBHOOK` — (optional) Slack webhook URL

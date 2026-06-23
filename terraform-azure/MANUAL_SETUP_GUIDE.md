# ArchGen Platform — Infrastructure Setup & Post-Provisioning Guide

This guide details the step-by-step process to deploy the Azure private cloud infrastructure using Terraform, bootstrap the remote state backend, configure the private jumpbox VM, provision required secrets in Azure Key Vault, and configure AGIC (Application Gateway Ingress Controller) for exposure.

---

## 1. Deploying the Infrastructure with Terraform

### 1.1 Phase 1: Bootstrap Storage Provisioning (Local State)
Before you can configure Terraform to store its state file in the remote Azure storage container, you must run it once locally to create that storage account.

1. Navigate to the environment folder you want to deploy (e.g. dev):
   ```bash
   cd terraform-azure/environments/dev
   ```
2. Create a file called `terraform.tfvars` containing your subscription details and naming parameters (Do **NOT** commit this file to git):
   ```hcl
   subscription_id      = "your-subscription-id"
   tenant_id            = "your-tenant-id"
   storage_account_name = "sttfstatedevpraveen" # Globally unique name
   acr_name             = "acrarchgendevpraveen" # Globally unique name
   keyvault_name        = "kvdevpraveen"        # Globally unique name
   cosmos_account_name  = "cosmosdevpraveen"    # Globally unique name
   ```
3. Initialize and apply:
   ```bash
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```
   *Note: Because of `prevent_destroy = true` lifecycle blocks on the storage account, container, and container registry (ACR), these resources cannot be destroyed by accident later.*

### 1.2 Phase 2: Migrate State to Remote Azure Blob Backend
Once the storage account is provisioned successfully:
1. Open `providers.tf` in the environment folder (`dev` or `prod`).
2. Uncomment the `backend "azurerm"` block and update the placeholder details:
   ```hcl
   backend "azurerm" {
     resource_group_name  = "rg-archgen-dev"
     storage_account_name = "sttfstatedevpraveen" # Replace with your storage account name
     container_name       = "tfstate"
     key                  = "dev.terraform.tfstate"
   }
   ```
3. Run the init command with the migration switch:
   ```bash
   terraform init -migrate-state
   ```
   *Terraform will ask for confirmation and securely copy your local state file into the Azure Storage container.*

---

## 2. Accessing the Private AKS Cluster via Bastion Jumpbox

Because the AKS cluster has `private_cluster_enabled = true` and all services are private, you cannot run `kubectl` commands from your local computer. You must connect to the private Linux Virtual Machine inside the Hub VNet.

### 2.1 Retrieve the Private SSH Key
Get the dynamically generated SSH private key from the Terraform outputs:
```bash
terraform output -raw ssh_private_key_pem > jumpbox_id_rsa
chmod 400 jumpbox_id_rsa
```

### 2.2 Connect via Azure Bastion Host
1. Log in to the [Azure Portal](https://portal.azure.com).
2. Navigate to your Resource Group (`rg-archgen-dev`).
3. Click on the Virtual Machine (`vm-jumpbox-dev`).
4. Click **Connect** $\rightarrow$ **Bastion**.
5. Enter the username (`praveen`), select **SSH Private Key from Local File**, and upload the `jumpbox_id_rsa` file.
6. Click **Connect**.

### 2.3 Setup Kubernetes Tools on the Jumpbox
Once logged into the VM console, run the following setup commands:
```bash
# Update packages
sudo apt-get update && sudo apt-get install -y curl apt-transport-https ca-certificates gnupg

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install kubectl
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/gpg.key
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update && sudo apt-get install -y kubectl

# Install Helm
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update && sudo apt-get install -y helm
```

### 2.4 Login and Load Kubeconfig
```bash
# Log in to Azure (Device Code authentication flow)
az login --use-device-code

# Get AKS kubeconfig credentials
az aks get-credentials --resource-group rg-archgen-dev --name aks-archgen-dev
```
*Verify cluster access: `kubectl get nodes` (should list the node pool scale-set virtual machines).*

---

## 3. Provisioning Azure Key Vault Secrets

Because the microservices retrieve their configuration files directly from Azure Key Vault, you must add the values to Key Vault (`kvpraveen`).

### 3.1 Upload Key Vault Secrets
Inside the Azure portal or jumpbox console, create the following secrets:

#### Core Secrets (Required by all services)
```bash
VAULT_NAME="kvdevpraveen" # Name of Key Vault

# JWT secret key for signing
az keyvault set-secret --vault-name $VAULT_NAME --name "dev-jwt-secret" --value "AStrongRandomHMACSignatureKeyForTokens"

# Cosmos DB MongoDB URI
# Retrieve connection string: az cosmosdb keys list --name <cosmos-account> --resource-group <rg> --type connection-strings
az keyvault set-secret --vault-name $VAULT_NAME --name "dev-cosmos-connection-string" --value "mongodb://cosmosdevpraveen:<key>@cosmosdevpraveen.mongo.cosmos.azure.com:10255/?ssl=true..."
```

#### API Gateway URLs
Configure gateway routing:
```bash
az keyvault set-secret --vault-name $VAULT_NAME --name "dev-gateway-port" --value "8080"
az keyvault set-secret --vault-name $VAULT_NAME --name "dev-auth-service-url" --value "http://archgen-dev-auth-service-auth-service:8001"
az keyvault set-secret --vault-name $VAULT_NAME --name "dev-project-service-url" --value "http://archgen-dev-project-service-project-service:8002"
az keyvault set-secret --vault-name $VAULT_NAME --name "dev-architecture-service-url" --value "http://archgen-dev-architecture-service-architecture-service:8003"
```

#### AI Provider Secrets (Architecture Service)
```bash
az keyvault set-secret --vault-name $VAULT_NAME --name "dev-openai-api-key" --value "sk-proj-..."
az keyvault set-secret --vault-name $VAULT_NAME --name "dev-deepseek-api-key" --value "sk-ds-..."
```

---

## 4. Bind Workload Identity Federated Credentials

Kubernetes pods authenticate to Key Vault via Microsoft Entra ID Workload Identity. The cluster's OIDC issuer signs the token and exchanges it for a managed identity token.

### 4.1 Create Federated Credentials
Map the managed identity `akspraveen-uami` to the service account names inside the namespaces on the jumpbox:
```bash
# Retrieve OIDC Issuer URL from AKS
OIDC_ISSUER=$(az aks show --name aks-archgen-dev --resource-group rg-archgen-dev --query "oidcIssuerProfile.issuerUrl" -o tsv)

# Create credentials for dev auth-service ServiceAccount
az identity federated-credential create \
  --name "fed-auth-dev" \
  --identity-name "akspraveen-uami" \
  --resource-group rg-archgen-dev \
  --issuer $OIDC_ISSUER \
  --subject "system:serviceaccount:dev:archgen-dev-auth-service-sa" \
  --audiences "api://AzureADTokenExchange"
```
*(Repeat the federated credential command for `project-service-sa`, `architecture-service-sa`, and `api-gateway-sa` inside namespaces `dev` and `prod`).*

---

## 5. Exposing the Application using AGIC

Because we configured Application Gateway Ingress Controller (AGIC) during AKS creation:
1. An Application Gateway is automatically provisioned inside the `snet-appgw` subnet of the Hub VNet.
2. An ingress controller pod (`ingress-appgw-deployment`) runs inside the `kube-system` namespace. It watches Kubernetes `Ingress` resources and automatically updates the Application Gateway backend pool and routing rules.

### 5.1 Update Ingress Manifests to Target AGIC
To route traffic through the Application Gateway, modify your `ingress.yaml` manifests in your Helm templates or raw manifests to specify the `azure/application-gateway` class:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: archgen-dev-frontend-ingress
  namespace: dev
  annotations:
    # Tell AGIC to configure Application Gateway for this Ingress
    kubernetes.io/ingress.class: azure/application-gateway
    # Set public listener frontend configurations
    appgw.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: archgen-dev-frontend-frontend
            port:
              number: 80
```
When this Ingress is applied:
1. AGIC binds the public IP of the Application Gateway to target the frontend pods.
2. The public IP address of the Application Gateway becomes the entry point for your browser! Get the IP:
   ```bash
   kubectl get ingress -n dev
   ```
   *Look at the `ADDRESS` column to find your public Application Gateway IP.*

# ArchGen Cloud Architecture & Deployment Guide

This guide details the design, security integration, namespace isolation, and continuous delivery patterns implemented for the ArchGen microservice platform.

---

## 1. Kubernetes Namespace Isolation (`dev` vs `prod`)

### What is a Namespace?
A Namespace in Kubernetes is a logical partition inside a single physical cluster. It provides a scope for resource names, resource allocation limits, and network policies.

### Why use Namespace separation?
1. **Logical Isolation**: Isolates development environments (`dev`) from customer-facing environments (`prod`).
2. **Access Control (RBAC)**: Allows setting strict Role-Based Access Control (e.g., developers can have access to modify resources in the `dev` namespace, but only the CI/CD system can deploy to the `prod` namespace).
3. **Resource Quotas**: Prevents memory or CPU leaks in a development pod from exhausting resources required for the production environment.
4. **Clean Domain Boundaries**: Pods communicate within their own namespace using short DNS names (e.g., `http://archgen-dev-auth-service`), preventing accidental cross-talk between dev apps and prod databases.

### How it is configured:
- Dev resources are defined in the directory `manifests/dev/` and are bounded by the `dev` namespace.
- Prod resources are defined in `manifests/prod/` and are bounded by the `prod` namespace.

---

## 2. Azure Key Vault Secrets Integration (`kvpraveen`)

### Why Key Vault instead of Kubernetes Secrets?
- **Zero Static Secret Storage**: Default Kubernetes `Secret` resources are only Base64 encoded and stored in plaintext in `etcd`. Compromising the cluster compromises all secrets.
- **GitOps Security**: Plain Kubernetes secret YAMLs cannot be committed to Git. Centralizing secrets in Key Vault allows committing the manifest structure securely.
- **Auditability**: Key Vault logs every single access request with a timestamp, ensuring compliance.

### How it works:
1. We use the **Azure Key Vault Secrets Store CSI Driver**.
2. When a pod starts, the CSI driver connects to Key Vault `kvpraveen`, retrieves the secrets (`dev-jwt-secret`, `dev-cosmos-connection-string`, etc.), and mounts them as files inside the container at `/mnt/secrets-store/`.
3. The driver uses the `secretObjects` configuration to automatically create a corresponding Kubernetes Secret containing the secret values.
4. The pod's deployment manifest then pulls the values from this Kubernetes Secret and injects them as standard environment variables (e.g., `JWT_SECRET_KEY`, `MONGO_URI`), allowing the application code to read them via standard system calls (`os.getenv`).

---

## 3. Workload Identity & Federated Credentials

### What is Workload Identity?
Workload Identity is a secure, passwordless authentication mechanism for workloads running in Kubernetes. Instead of mounting a static, long-lived client secret (which can leak or expire), pods authenticate with Azure using a temporary OIDC (OpenID Connect) token.

### Why use it?
- **No Client Secrets**: Eliminates the operational overhead of managing, rotating, and securing credentials.
- **Minimum Privilege**: Access is granted only to the specific service accounts in the specific namespaces.
- **Auto-Rotation**: The OIDC token is automatically rotated by the Kubernetes API server and Azure Active Directory every hour.

### How it works:
1. AKS acts as an **OIDC Issuer**, signing tokens generated for Kubernetes Service Accounts.
2. A user-assigned managed identity (`akspraveen-uami`) is created in Azure with permission to read secrets from Key Vault (`kvpraveen`).
3. We set up **Federated Identity Credentials** linking the managed identity to specific subjects:
   - For dev: `system:serviceaccount:dev:archgen-dev-auth-service-sa`
   - For prod: `system:serviceaccount:prod:archgen-prod-auth-service-sa`
4. When the pod starts, the workload identity webhook injects the token path and managed identity client ID into the pod environment. The Azure SDK in the container uses this token to authenticates and gain access to Key Vault.

---

## 4. GitOps Continuous Delivery (ArgoCD)

### What is ArgoCD?
ArgoCD is a declarative continuous delivery tool designed specifically for Kubernetes. It follows the GitOps pattern: using a Git repository as the single source of truth for the desired system state.

### Why use it?
- **Automated Drift Detection**: ArgoCD compares the running state of the cluster with the manifests in Git. If someone manually changes a configuration on the cluster, ArgoCD flags it as "OutOfSync" and automatically syncs it back to match Git.
- **History and Audit Trails**: Every deployment corresponds to a Git commit, providing an instant history of changes.

### Configuration (`argocd/` manifests):
- **`dev-application.yaml`**: Listens to the `dev` branch of the `Main` repo and synchronizes the manifests under `manifests/dev` to the `dev` namespace.
- **`prod-application.yaml`**: Listens to the `master` branch of the `Main` repo and synchronizes the manifests under `manifests/prod` to the `prod` namespace.

---

## 5. Ingress Routing & Port Mapping

### Port Mapping Fix (Next.js Port 3000)
By default, Next.js applications listen on port `3000`. However, the original Kubernetes manifest specified `containerPort: 80`. This mismatch caused the ingress controller to throw a `502 Bad Gateway` error.
- **Fix**: We updated `containerPort` in the deployment manifests to `3000`, keeping the service `targetPort` mapped to the named port `http`.

### Unified Nginx Ingress
To make the application instantly accessible without requiring the user to edit local hosts files or purchase DNS records:
1. We deployed the **Nginx Ingress Controller** which was assigned the public IP `48.206.132.190`.
2. We unified the ingress resources into a single ingress per namespace without host restrictions (`host: *`).
3. Routing:
   - `http://48.206.132.190/` $\rightarrow$ `archgen-dev-frontend` (Port 3000)
   - `http://48.206.132.190/api` $\rightarrow$ `archgen-dev-api-gateway` (Port 8080)
4. The frontend code was configured with a relative base API URL (`""`), ensuring the browser sends all API requests relative to the public IP.

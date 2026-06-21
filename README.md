# Main Infrastructure Repository (Modular GitOps & Reusable CI/CD)

This is the main infrastructure repository containing the Kubernetes Helm charts for all microservices under `k8s/` and the modular, reusable GitHub Actions pipeline.

---

## 1. Pipeline Architecture

The pipeline structure is modularized into reusable workflows and GitOps controller workflows:

### A. Reusable CI/CD Workflows
- **[backend.yml](.github/workflows/backend.yml)**: Handles standard checks for all Python backend microservices.
- **[frontend.yml](.github/workflows/frontend.yml)**: Handles dependency caching, testing, building, and security checks for the Next.js Frontend.

Both workflows handle two main triggers (via inputs):
- **Pull Request Checks (`pr-checks` job)**: Triggered by PRs to `master`. Runs linting, SonarQube quality checks, and Snyk dependency scanning. Sends alerts on failure/success.
- **Master Branch Builds (`build` job)**: Triggered by merges/pushes to `master`. Compiles the Docker image, runs a Trivy CVE scan, publishes the image to the registry (`acrarchgen.azurecr.io`) using a `sha-<commit-sha>` tag, dispatches an image update event to the Main repository, and alerts.

### B. GitOps Controller Workflows
- **[deploy-dev.yml](.github/workflows/deploy-dev.yml)**: Triggered by `repository_dispatch` (event: `service-image-updated`). Automatically checks out the `dev` branch, updates `k8s/<service>/values-dev.yaml` with the new tag using `yq`, commits and pushes to `dev`, and sends notifications.
- **[release-prod.yml](.github/workflows/release-prod.yml)**: Triggered by publishing a GitHub Release (`release: [published]`). It parses the tag name (expects `<service-name>-v<version>`, e.g. `api-gateway-v1.0.0`), pulls the corresponding dev container image, retags it as the release version, pushes it to ACR, updates `values-prod.yaml` on `master` branch using `yq`, and commits/pushes to `master`.

---

## 2. Guide to Generating Repository Secrets

To run this pipeline successfully, you must configure the following **Repository Secrets** in each microservice repository (`Settings` -> `Secrets and variables` -> `Actions` -> `New repository secret`):

### 1. `GH_PAT` (GitHub Personal Access Token)
*Required. Needed to checkout/push changes to this Main repository and trigger Repository Dispatches.*
1. Go to your GitHub profile settings: `Settings` -> `Developer settings` -> `Personal access tokens` -> `Tokens (classic)`.
2. Click **Generate new token** -> **Generate new token (classic)**.
3. Name it (e.g. `gitops-token`) and select the `repo` checkbox (grants full access to modify repositories).
4. Click **Generate token** and copy it immediately.
5. Save this as `GH_PAT` in your service repository secrets.

### 2. `AZURE_CREDENTIALS` (Azure Service Principal)
*Required. Needed to authenticate and push container images to Azure Container Registry (`acrarchgen.azurecr.io`).*
1. Open the Azure CLI or Cloud Shell.
2. Run:
   ```bash
   az ad sp create-for-rbac --name "github-actions-sp" --role contributor --scopes /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP_NAME> --sdk-auth
   ```
3. Copy the output JSON block and save it as `AZURE_CREDENTIALS` in your repository secrets.

### 3. `SLACK_WEBHOOK` (Slack Notification Webhook)
*Optional. Set up to send status cards directly to your Slack channel.*
1. Create a Slack App in your workspace via the [Slack API console](https://api.slack.com/apps).
2. Activate **Incoming Webhooks** and click **Add New Webhook to Workspace**.
3. Choose the target channel, authorize, and copy the Webhook URL.
4. Save this as `SLACK_WEBHOOK` in your repository secrets.

### 4. SonarCloud & Snyk Secrets
*Optional. Configure these to enable static code security analysis and library scanning.*
- `SONAR_TOKEN`: API token generated from SonarCloud (`My Account` -> `Security`).
- `SONAR_KEY`: (Optional) Custom Sonar project key (defaults to `ArchGenTf_<service-name>`).
- `SNYK_TOKEN`: Snyk API token generated from Snyk account settings.

# Main Infrastructure Repository (GitOps & Centralized CI/CD)

This is the main infrastructure repository containing the Kubernetes Helm charts for all microservices under `k8s/` and the centralized, reusable GitHub Actions pipeline.

---

## 1. Centralized Reusable Pipeline

The pipeline is defined in [reusable-pipeline.yml](.github/workflows/reusable-pipeline.yml). It standardizes the build, test, scan, and deploy stages across all services:

### CI / Dev Phase (`ci-dev` job)
1. **Lint Check**: Custom linter executed if a lint command is passed.
2. **SonarQube Cloud**: Static code analysis check.
3. **Snyk Scan**: Analyzes application dependencies for high/critical security vulnerabilities.
4. **Docker Image Build**: Compiles the application image, tagged with the Git commit SHA.
5. **Local Smoke Test**: Spins up the container on a runner, curls the health endpoint to verify startup success, and cleans it up.
6. **Trivy Image Scan**: Identifies OS and library CVEs inside the image.
7. **ACR Dev Push**: Publishes the image to the Dev Azure Container Registry.
8. **GitOps Dev Update**: Checks out the `Main` repo, switches to the `dev` branch, updates `values-dev.yaml`'s image tag using `yq`, and pushes it.

### CD / Prod Phase (`promote-prod` job)
1. **Approval Gate**: Execution pauses for a manual approval review in the `production` environment.
2. **ACR Promotion**: Copies the verified dev image into the Prod ACR.
3. **GitOps Prod Update**: Checks out the `Main` repo on `master` branch, updates `values-prod.yaml`'s image tag, and pushes it.

---

## 2. Guide to Generating Repository Secrets

To run this pipeline successfully, you must add the following **Repository Secrets** in the GitHub Settings page of each service repository (`Settings` -> `Secrets and variables` -> `Actions` -> `New repository secret`):

### 1. `PAT_TOKEN` (GitHub Personal Access Token)
*Needed to check out and push image tag updates to this Main repository.*
1. Go to your GitHub profile settings: `Settings` -> `Developer settings` -> `Personal access tokens` -> `Tokens (classic)`.
2. Click **Generate new token** -> **Generate new token (classic)**.
3. Set the note (e.g., `gitops-infra-token`) and check the `repo` scope checkbox.
4. Click **Generate token** and copy it immediately.
5. Save this as `PAT_TOKEN` in your service repository secrets.

### 2. `AZURE_CREDENTIALS` (Azure Service Principal)
*Needed to authenticate and push/promote container images to Azure Container Registries.*
1. Open the Azure CLI or Cloud Shell.
2. Generate a Service Principal JSON payload by running:
   ```bash
   az ad sp create-for-rbac --name "github-actions-sp" --role contributor --scopes /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP_NAME> --sdk-auth
   ```
   *(Replace `<SUBSCRIPTION_ID>` and `<RESOURCE_GROUP_NAME>` with your Azure environment details)*
3. Copy the output JSON block.
4. Save this as `AZURE_CREDENTIALS` in your service repository secrets.

### 3. `SLACK_WEBHOOK` (Slack Incoming Webhook URL)
*Needed to send pipeline success/failure alerts to Slack.*
1. Create a Slack App in your workspace via the [Slack API console](https://api.slack.com/apps).
2. Go to **Incoming Webhooks** and toggle it **On**.
3. Click **Add New Webhook to Workspace**, select the target channel, and click **Allow**.
4. Copy the generated Webhook URL (starts with `https://hooks.slack.com/services/`).
5. Save this as `SLACK_WEBHOOK` in your service repository secrets.

### 4. `SONAR_TOKEN` (SonarCloud API Token)
*Needed for static code analysis scans.*
1. Log in to [SonarCloud](https://sonarcloud.io/).
2. Click your profile avatar -> **My Account** -> **Security**.
3. Generate a token (e.g., `github-actions-sonar`) and copy it.
4. Save this as `SONAR_TOKEN` in your service repository secrets.

### 5. `SNYK_TOKEN` (Snyk Security API Token)
*Needed for package vulnerability scans.*
1. Log in to [Snyk](https://snyk.io/).
2. Click your profile menu at the bottom-left -> **Account settings**.
3. Copy your API Token.
4. Save this as `SNYK_TOKEN` in your service repository secrets.

---

## 3. Production Promotion & GitOps Release Flow

This pipeline uses an automated, Git-driven release flow rather than manual environments:
1. **Develop Deployment**: Merges to the `master` branch automatically deploy code changes to the Dev cluster (updating `values-dev.yaml` on the `dev` branch of this `Main` repo with the commit SHA tag).
2. **Production Release**: When ready for a production release, create and publish a GitHub Release with a tag matching `v*` (e.g. `v1.0.0`) in the service repository.
3. The promotion pipeline will automatically find the pre-built image corresponding to that commit SHA, tag it with the release tag (e.g., `v1.0.0`), and push the new tag. It will then update `values-prod.yaml` on the `master` branch of this `Main` repository with the release tag.

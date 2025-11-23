
# IQLine Project — DevOps Assignment

**Repository**: https://github.com/bhardwajcr7/iqline-project  
**Demo URL / DNS**: iqline.pscloud.in

---
## 1) Project summary
Small microservices demo using 3 services:
- User Service (Node.js)
- Order Service (Node.js)
- API Gateway (Node.js)

Infrastructure deployed on Azure using Terraform:
- AKS cluster (iqlineproject-aks)
- ACR (iqlineprojectacr.azure.io)
- Key Vault (https://iqlineproject-kv.vault.azure.net/)
- Application Insights (iqlineproject-ai)
- Log Analytics workspace (iqlineproject-law)
- VNet and Subnet for AKS
- Cert-manager + Ingress for TLS

CI/CD: GitHub Actions building images, running tests, pushing to ACR, updating AKS deployments.

Notes: this README documents the infra, deployment steps, and verification commands you used in the assignment environment.

---
## 2) Architecture (ASCII)
```
                                     Internet
                                        |
                                      DNS
                                        |
                                  Public LB / Ingress
                                        |
                               +--------------------+
                               |    ingress-nginx   |
                               |  (cert-manager TLS)|
                               +--------------------+
                                /       |         \
                               /        |          \
                    api-gateway svc   user svc    order svc
                    (ClusterIP)       (ClusterIP)  (ClusterIP)
                         |                |            |
                   pods (gateway)    pods (user)   pods (order)
                         \                |           /
                          \               |          /
                           \              |         /
                            \             |        /
                            +----------------------+
                            |         AKS          |
                            +----------------------+
                                   |       |
                              Nodepool   Monitoring (AMA)
                                   |
                              ManagedIdentity (kubelet)
                                   |
                                ACR (iqlineprojectacr.azure.io)
                                   |
                                Key Vault (secrets)
                                   |
                         Log Analytics + App Insights
```
Diagram file included: `/mnt/data/DevOps_Assignment_Azure_With_Diagram 1.pdf` (see downloads)

---
## 3) Repo layout (recommended)
```
/terraform
  /modules
    /acr
    /aks
    /keyvault
    /loganalytics
    /appinsights
    /network
  /stacks
    /dev
      main.tf, dev.tfvars
/k8s
  namespace.yaml
  rbac.yaml
  user-deployment.yaml
  order-deployment.yaml
  gateway-deployment.yaml
  ingress.yaml
  cluster-issuer.yaml
/services
  /user-service
    server.js, Dockerfile, package.json, tests
  /order-service
  /api-gateway
.github/workflows/ci-cd-aks.yaml
README.md
```
---
## 4) Values observed in your environment
- ACR login server: `iqlineprojectacr.azure.io`
- Resource group: `iqlineproject-rg`
- Key Vault URI: `https://iqlineproject-kv.vault.azure.net/`
- Log Analytics workspace id: `/subscriptions/c84a106e-d18e-4ce4-bf1f-7d00bdae231f/resourceGroups/iqlineproject-rg/providers/Microsoft.OperationalInsights/workspaces/iqlineproject-law`
- AKS name: `iqlineproject-aks`

Adjust the above if you changed names during apply.

---
## 5) Prerequisites (local & GitHub)
Local:
- Azure CLI (2.80+)
- Terraform (>=1.3.0)
- kubectl
- docker (for local builds)
- node (18+) for running tests

GitHub secrets (minimum):
- `AZURE_CREDENTIALS` — service principal JSON (clientId, clientSecret, tenantId, subscriptionId) OR use OIDC federated credentials (recommended).
- `ACR_NAME` — e.g. `iqlineprojectacr`
- `AKS_RESOURCE_GROUP` — e.g. `iqlineproject-rg`
- `AKS_CLUSTER_NAME` — e.g. `iqlineproject-aks`

If using service principal with secret, ensure the SP has:
- `AcrPush` role scoped to ACR (to push images)
- `Azure Kubernetes Service Cluster User Role` (or specific `Microsoft.ContainerService/managedClusters/listClusterUserCredential/action`) to get AKS credentials for kubectl (or use kubeconfig stored securely)
- If you prefer OIDC: create federated credential for GitHub Actions and grant minimal RBAC roles to that identity.

---
## 6) Terraform: how this repo provisions infra (quick commands)
1. initialize stack (run from `terraform/stacks/dev`):
```bash
terraform init
terraform validate
terraform plan -var-file=dev.tfvars
```
2. to apply (if resources already exist, import them first):
```bash
# import existing rg if needed (example)
terraform import azurerm_resource_group.main "/subscriptions/<sub_id>/resourceGroups/iqlineproject-rg"

# then apply
terraform apply -var-file=dev.tfvars
```
3. Outputs to look for after apply:
- `acr_login_server`
- `app_insights_instrumentation_key` (sensitive)
- `key_vault_uri`
- `log_analytics_id`

Common terraform gotchas you hit:
- Some Azure resources already existed — import them before apply
- Key Vault access policies required the identity that runs Terraform to have secret permissions; either allow current user/service principal or use `access_policy` / RBAC correctly
- AKS monitoring addon can be enabled via `az aks enable-addons --addons monitoring --workspace-resource-id <law-id>` or via AKS resource config in Terraform (API changes may require provider version alignment).

---
## 7) Kubernetes: deploy order (manual steps)
1. Ensure kubeconfig is set (locally or in CI) — `az aks get-credentials -g <rg> -n <cluster>`
2. Create namespace and RBAC:
```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/rbac.yaml
```
3. Create the app-insights secret in `microservices` namespace (example):
```bash
kubectl create secret generic app-insights -n microservices --from-literal=ikey="<APPINSIGHTS_INSTRUMENTATIONKEY>"
```
Alternative: use Key Vault to provide secrets via CSI driver or Azure Key Vault provider (recommended for production).
4. Apply deployments & services:
```bash
kubectl apply -f k8s/user-deployment.yaml
kubectl apply -f k8s/order-deployment.yaml
kubectl apply -f k8s/gateway-deployment.yaml
```
5. Apply ingress + cert-manager:
```bash
kubectl apply -f k8s/cluster-issuer.yaml  # cert-manager issuer (letsencrypt/staging or prod)
kubectl apply -f k8s/ingress.yaml
```
6. Verify pods, services, and ingress:
```bash
kubectl get pods -n microservices
kubectl get svc -n microservices
kubectl get ingress -n microservices
kubectl describe certificate -n microservices
kubectl logs -n cert-manager deploy/cert-manager
```

---
## 8) CI/CD (GitHub Actions) — what your workflow does (and prerequisites)
Your `CI-CD-AKS` workflow:
- Triggers on `push` to `main`
- Logs into Azure (via service principal/certs or OIDC)
- Builds images for each service and runs `npm test`
- Pushes images to ACR using `docker push`
- Uses `azure/aks-set-context@v3` to set kubeconfig in the runner
- Uses `kubectl set image` to update deployments (image update only)

GitHub Secrets / Permissions required:
- `AZURE_CREDENTIALS` (SP JSON) or OIDC federated identity configured in Azure AD
- `ACR_NAME`
- `AKS_RESOURCE_GROUP`
- `AKS_CLUSTER_NAME`

Common failure points you saw:
- `No subscriptions found for ***` — SP JSON missing subscription or wrong app credentials
- `UNAUTHORIZED` during docker push — SP must have AcrPush role on ACR or use `az acr login` via managed identity
- `aks-set-context` failed — SP missing `listClusterUserCredential` permission; assign `Azure Kubernetes Service Cluster User Role` to the principal or use cluster admin context stored in secure place for CI.

Optimizations (only redeploy changed services):
- Instead of always building all services, compute changed paths in Git and build only changed services.
- In workflow, add a step to detect changed services (git diff --name-only) and conditionally run build jobs per service.

---
## 9) Key Vault integration — where & why used
Why used:
- Store instrumentation keys, database credentials, and secrets securely instead of plain Kubernetes secrets
Where used in assignment:
- Application Insights instrumentation key stored in Key Vault (secret name `app-insights-key`)
- Key Vault is mounted/consumed by CI/CD via service principal or by pods via Azure Key Vault Provider for Secrets Store CSI driver (recommended)

How to verify a pod reads secret (examples):
1. If using Kubernetes secret synced from Key Vault, check `kubectl get secret app-insights -n microservices -o yaml` and verify presence (or check keys are set as environment variables inside pod):
```bash
kubectl exec -it deploy/user-deployment -n microservices -- env | grep APPINSIGHTS
```
2. If using the CSI driver, verify `SecretProviderClass` usage and mounted file under `/mnt/secrets-store/` inside the container:
```bash
kubectl exec -it <pod> -n microservices -- ls /mnt/secrets-store
kubectl exec -it <pod> -n microservices -- cat /mnt/secrets-store/app-insights-key
```

---
## 10) Monitoring & App Insights — how to validate
- AKS monitoring addon should deploy AMA pods in kube-system (ama-logs, ama-metrics). Verify:
```bash
kubectl get pods -n kube-system | grep ama
kubectl top pod -A --sort-by=cpu
```
- Application Insights: your app must send telemetry using instrumentation key or connection string. Verify in Azure portal or use CLI queries (Log Analytics / App Insights). You tried several CLI queries that returned `PathNotFoundError` — that usually means either wrong workspace/app ID or insufficient permissions. Use the workspace ID from terraform outputs.
- If you want to enable Grafana integration: it may incur cost if using managed Grafana or if querying Log Analytics heavily. Watch Log Analytics ingestion and retention costs.

---
## 11) Autoscaling & cost optimization
- Node pool uses `Standard_B2s` in dev; autoscaling enabled: min 1, max 3. Good for cost control.
- Use HPA for pods (gateway HPA already configured in `k8s/hpa.yaml`).
- Use lower retention and apply ingestion caps on Log Analytics if needed to control cost.

---
## 12) Testing matrix in CI
- `npm test` runs unit tests (jest)
- `supertest` for minimal integration tests
- Keep tests fast; run slow integration tests in separate job

---
## 13) RBAC & Security checks
- You created `app-sa` service account and Role/RoleBinding limited to `get` on secrets/configmaps. This limits app access to only those secrets in namespace.
- Key Vault access controlled by Azure RBAC or Key Vault access policies — ensure only necessary identities have access.

---
## 14) Cleanup
To tear down everything created by Terraform (but be careful if you imported resources):
```bash
terraform destroy -var-file=dev.tfvars
# or selectively delete via az cli for resources you created manually
```
Also remove any GitHub secrets and OIDC setup if created for the assignment.

---
## 15) Troubleshooting notes (things you hit)
- `PathNotFoundError` when querying App Insights: verify appId vs resource name and use correct CLI extension (`az monitor app-insights query` requires correct extension/version).
- Key Vault 403 when writing/reading secrets from Terraform: ensure the identity running Terraform has `set`/`get`/`list` permissions via access policy or RBAC.
- `UNAUTHORIZED` pushing to ACR: grant AcrPush to the principal you use in CI or use `az acr login` with managed identity.
- `aks-set-context` failure: grant `Azure Kubernetes Service Cluster User Role` to the principal, or configure proper OIDC federated identity.

---
## 16) Next steps (suggested)
- Wire Key Vault to pods via Secrets Store CSI driver (avoid copying secrets to k8s secrets in prod)
- Move GitHub Actions to OIDC federation (no client secret)
- Add selective build/deploy logic (only deploy changed services)
- Improve tests (unit + integration, and add smoke tests)
- Add cost alerts for Log Analytics ingestion and set retention to 30 days for dev, 90 days for prod if needed

---
## 17) Useful commands (quick cheatsheet)
```bash
# terraform
terraform init
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars

# kubernetes
az aks get-credentials -g iqlineproject-rg -n iqlineproject-aks
kubectl get pods -n microservices
kubectl logs -n microservices deploy/gateway-deployment
kubectl exec -it deploy/user-deployment -n microservices -- env | grep APPINSIGHTS

# verify monitoring
kubectl get pods -n kube-system | grep ama
kubectl top pod -A --sort-by=cpu
```
---
## 18) Artifacts for this assignment
- Terraform stack: `terraform/stacks/dev`
- Kubernetes manifests: `k8s/`
- GitHub workflow: `.github/workflows/ci-cd-aks.yaml`
- Architecture PDF: `/mnt/data/DevOps_Assignment_Azure_With_Diagram 1.pdf`

---
## 19) Contact / authoring notes
This README was generated for your assignment. Tweak any resource names or instructions to match any renames you performed while provisioning.


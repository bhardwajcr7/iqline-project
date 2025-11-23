# Terraform stack: dev (Option A - simple)

This stack provisions infrastructure required for the DevOps assignment:
- Azure Container Registry (ACR)
- Log Analytics Workspace
- Application Insights
- Key Vault with App Insights secret
- AKS cluster (with monitoring enabled)
- Role assignments (ACR pull by AKS, optional CI AKS user)

How to run:
1. cd terraform/stacks/dev
2. terraform init
3. terraform plan -var-file=dev.tfvars
4. terraform apply -var-file=dev.tfvars

Notes:
- Replace creator_object_id in dev.tfvars with `az ad signed-in-user show --query id -o tsv`.
- If you want CI to get AKS credentials, set `ci_object_id` to the object id of your CI service principal.
- App Insights key is stored in Key Vault secret named "app-insights-key".
- The architecture diagram file included in outputs is referenced at:
  /mnt/data/DevOps_Assignment_Azure_With_Diagram 1.pdf

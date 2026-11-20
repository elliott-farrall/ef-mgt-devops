locals {
  deployments = {
    for name in var.environments : "ef-${name}-${var.name}" => {
      environment               = name
      tfc_project_id            = var.tfc_project_ids[name]
      folder_id                 = var.folder_ids[name]
      wif_provider              = var.wif_providers[name]
      gcp_service_account_email = var.gcp_service_account_emails[name]
      queue_all_runs            = name == var.environments[0]
    }
  }

  labels = {
    managed_by = "terraform"
    repository = var.repo
  }

  workspace_trigger_patterns = ["infrastructure/**", "environments/**"]

  project_services = { for pair in flatten([
    for key, deployment in local.deployments : [
      for service in local.services : {
        key        = "${key}-${service}"
        deployment = key
        service    = service
      }
    ]
  ]) : pair.key => pair }

  workspace_variables = { for pair in flatten([
    for key, deployment in local.deployments : [
      for variable in [
        { key = "environment", value = deployment.environment, category = "terraform", description = "Environment slot this workspace deploys." },
        { key = "TFC_GCP_PROVIDER_AUTH", value = "true", category = "env", description = "Enables HCP Terraform dynamic credentials for the Google provider in this run." },
        { key = "TFC_GCP_WORKLOAD_IDENTITY_PROVIDER", value = deployment.wif_provider, category = "env", description = "Workload identity provider this run authenticates through; consumed by the Google provider." },
        { key = "TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL", value = deployment.gcp_service_account_email, category = "env", description = "Service account this run impersonates after workload identity token exchange." },
      ] : { key = "${key}-${variable.key}", workspace = key, variable = variable }
    ]
  ]) : pair.key => pair }

  trigger_pairs = {
    for i in range(1, length(var.environments)) : "ef-${var.environments[i]}-${var.name}" => "ef-${var.environments[i - 1]}-${var.name}"
  }

  services = [for service in var.services : "${service}.googleapis.com"]

  status_checks = concat(
    ["ci / branch-name (pull_request)", "ci / terraform (pull_request)", "ci / yaml (pull_request)", "ci / shell (pull_request)"],
    [for name in keys(local.deployments) : "Terraform Cloud / ${name} (Predict)"],
  )
}

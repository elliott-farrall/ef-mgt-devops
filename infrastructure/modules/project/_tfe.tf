resource "tfe_workspace" "this" {
  name              = var.name
  project_id        = var.project_id
  working_directory = var.working_directory
  auto_apply        = false

  vcs_repo {
    identifier                 = "${var.github_owner}/${var.repo}"
    branch                     = "main"
    github_app_installation_id = data.tfe_github_app_installation.this.id
  }

}

resource "tfe_workspace_settings" "this" {
  workspace_id   = tfe_workspace.this.id
  execution_mode = "remote"
}

resource "tfe_variable" "environment" {
  key          = "environment"
  value        = var.environment
  category     = "terraform"
  workspace_id = tfe_workspace.this.id
  description  = "Environment slot this workspace deploys."
}

resource "tfe_variable" "gcp_provider_auth" {
  key          = "TFC_GCP_PROVIDER_AUTH"
  value        = "true"
  category     = "env"
  workspace_id = tfe_workspace.this.id
  description  = "Enables HCP Terraform dynamic credentials for the Google provider in this run."
}

resource "tfe_variable" "gcp_workload_identity_provider" {
  key          = "TFC_GCP_WORKLOAD_IDENTITY_PROVIDER"
  value        = var.wif_provider
  category     = "env"
  workspace_id = tfe_workspace.this.id
  description  = "Workload identity provider this run authenticates through; consumed by the Google provider."
}

resource "tfe_variable" "gcp_run_service_account" {
  key          = "TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL"
  value        = var.gcp_service_account_email
  category     = "env"
  workspace_id = tfe_workspace.this.id
  description  = "Service account this run impersonates after workload identity token exchange."
}

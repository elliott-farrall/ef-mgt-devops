resource "tfe_workspace" "this" {
  name              = var.name
  project_id        = var.project_id
  working_directory = var.working_directory
  auto_apply        = var.auto_apply

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

resource "tfe_variable" "wif_provider" {
  key          = "WIF_PROVIDER"
  value        = var.wif_provider
  category     = "env"
  workspace_id = tfe_workspace.this.id
  description  = "Workload identity provider this workspace authenticates through, exposed to the run environment."
}

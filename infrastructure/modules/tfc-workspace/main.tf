resource "tfe_workspace" "this" {
  name              = var.name
  project_id        = var.project_id
  working_directory = var.working_directory
  auto_apply        = var.auto_apply

  vcs_repo {
    identifier                 = "${var.github_owner}/${var.name}"
    branch                     = "main"
    github_app_installation_id = var.github_app_installation_id
  }
}

resource "tfe_workspace_settings" "this" {
  workspace_id   = tfe_workspace.this.id
  execution_mode = "remote"
}

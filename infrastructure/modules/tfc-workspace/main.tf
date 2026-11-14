resource "tfe_workspace" "this" {
  name              = var.name
  organization      = var.organisation
  project_id        = var.project_id
  working_directory = var.working_directory
  auto_apply        = var.auto_apply
}

resource "tfe_workspace_settings" "this" {
  workspace_id   = tfe_workspace.this.id
  execution_mode = "remote"
}

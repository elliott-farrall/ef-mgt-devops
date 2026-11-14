# Terraform Cloud structure: one project per plane (mirroring the GCP
# folders) and this repository's workspace. Created by
# scripts/bootstrap/02-tfc.sh and adopted via import.

data "tfe_organization" "ef" {
  name = var.config.tfc_organization
}

resource "tfe_project" "planes" {
  for_each = toset(var.config.tfc_projects)

  name         = each.value
  organization = data.tfe_organization.ef.name
}

resource "tfe_workspace" "this" {
  name              = var.config.tfc_workspace
  organization      = data.tfe_organization.ef.name
  project_id        = tfe_project.planes["ef-mgt"].id
  working_directory = "infrastructure"
  auto_apply        = false # mgt plane: manual confirm — see run policy

  # VCS connection is attached at bootstrap Step 5 (TFC GitHub App), then
  # this block is managed here:
  # vcs_repo {
  #   identifier = "elliott-farrall/ef-mgt-devops"
  #   branch     = "main"
  # }
}

resource "tfe_workspace_settings" "this" {
  workspace_id   = tfe_workspace.this.id
  execution_mode = "remote"
}

# TODO (bootstrap prep): global variable set (org/billing/CF account IDs),
# workspace `environment` variable, OAuth/app linkage at Step 5.

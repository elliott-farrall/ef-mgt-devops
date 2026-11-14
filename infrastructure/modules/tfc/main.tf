data "tfe_organization" "ef" {
  name = var.organisation
}

resource "tfe_project" "planes" {
  for_each = toset(var.projects)

  name         = each.value
  organization = data.tfe_organization.ef.name
}

resource "tfe_workspace" "registry" {
  for_each = var.workspaces

  name              = each.value.name
  organization      = data.tfe_organization.ef.name
  project_id        = tfe_project.planes[each.value.project].id
  working_directory = each.value.working_directory
  auto_apply        = each.value.auto_apply

}

resource "tfe_workspace_settings" "registry" {
  for_each = tfe_workspace.registry

  workspace_id   = each.value.id
  execution_mode = "remote"
}


data "tfe_organization" "ef" {
  name = var.config.organization
}

resource "tfe_project" "planes" {
  for_each = toset(var.config.projects)

  name         = each.value
  organization = data.tfe_organization.ef.name
}

resource "tfe_workspace" "registry" {
  for_each = { for w in var.config.workspaces : w.name => w }

  name              = each.value.name
  organization      = data.tfe_organization.ef.name
  project_id        = tfe_project.planes[each.value.project].id
  working_directory = each.value.working_directory
  auto_apply        = each.value.auto_apply

  # Step 5 attaches the VCS repo via the GitHub App integration; the token ID
  # comes from data.tfe_organization_integration (API: integrations/github):
  # vcs_repo {
  #   identifier     = "${var.config.organization}/${each.value.repo}"
  #   branch         = "main"
  #   oauth_token_id = data.tfe_organization_integration.github.id
  # }
}

resource "tfe_workspace_settings" "registry" {
  for_each = tfe_workspace.registry

  workspace_id   = each.value.id
  execution_mode = "remote"
}

# TODO (bootstrap prep): global variable set (org/billing/CF account IDs) and
# the tfe_organization_integration data source once the GitHub App is installed.

data "tfe_github_app_installation" "this" {
  name = var.github_app_installation
}

resource "tfe_registry_module" "this" {
  name            = var.name
  organization    = var.organization
  module_provider = var.module_provider
  registry_name   = "private"

  vcs_repo {
    identifier                 = var.repository
    github_app_installation_id = data.tfe_github_app_installation.this.id
  }
}

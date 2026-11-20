module "repository" {
  source = "../repository"

  repo          = "ef-lib-${var.name}"
  description   = var.description
  settings      = var.settings
  protection    = var.protection
  status_checks = ["ci / branch-name (pull_request)", "ci / terraform (pull_request)", "ci / yaml (pull_request)", "ci / shell (pull_request)"]
  zone          = var.zone
  github_owner  = var.github_owner
}

resource "tfe_registry_module" "this" {
  name            = var.name
  organization    = var.organization
  module_provider = var.module_provider
  registry_name   = "private"

  vcs_repo {
    identifier                 = "${var.github_owner}/ef-lib-${var.name}"
    github_app_installation_id = data.tfe_github_app_installation.this.id
  }

  depends_on = [module.repository]
}

data "tfe_github_app_installation" "this" {
  name = var.github_app_installation
}

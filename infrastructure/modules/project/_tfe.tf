module "repository" {
  source = "../repository"

  repo          = var.repo
  description   = var.description
  settings      = var.settings
  protection    = var.protection
  status_checks = local.status_checks
  pages         = var.pages
  cname         = var.cname
  zone          = var.zone
  github_owner  = var.github_owner
}

resource "google_project" "this" {
  for_each = local.deployments

  name            = each.key
  project_id      = each.key
  folder_id       = each.value.folder_id
  billing_account = var.billing_account_id
  labels          = merge(local.labels, { environment = each.value.environment })
  deletion_policy = "PREVENT"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_project_service" "this" {
  for_each = local.project_services

  service            = each.value.service
  project            = google_project.this[each.value.deployment].project_id
  disable_on_destroy = false
}

resource "tfe_workspace" "this" {
  for_each = local.deployments

  name              = each.key
  project_id        = each.value.tfc_project_id
  working_directory = var.working_directory
  auto_apply        = false
  queue_all_runs    = each.value.queue_all_runs
  trigger_patterns  = local.workspace_trigger_patterns

  vcs_repo {
    identifier                 = "${var.github_owner}/${var.repo}"
    branch                     = "main"
    github_app_installation_id = data.tfe_github_app_installation.this.id
  }

  depends_on = [module.repository]
}

resource "tfe_workspace_settings" "this" {
  for_each = local.deployments

  workspace_id   = tfe_workspace.this[each.key].id
  execution_mode = "remote"
}

resource "tfe_variable" "this" {
  for_each = local.workspace_variables

  key          = each.value.variable.key
  value        = each.value.variable.value
  category     = each.value.variable.category
  workspace_id = tfe_workspace.this[each.value.workspace].id
  description  = each.value.variable.description
}

resource "tfe_run_trigger" "this" {
  for_each = local.trigger_pairs

  workspace_id  = tfe_workspace.this[each.key].id
  sourceable_id = tfe_workspace.this[each.value].id
}

locals {
  deployments = {
    for name in var.environments : "ef-${name}-${var.name}" => {
      environment               = name
      tfc_project_id            = var.tfc_project_ids[name]
      folder_id                 = var.folder_ids[name]
      wif_provider              = var.wif_providers[name]
      gcp_service_account_email = var.gcp_service_account_emails[name]
      queue_all_runs            = name == var.environments[0]
    }
  }

  labels = {
    managed_by = "terraform"
    repository = var.repo
  }

  workspace_trigger_patterns = ["infrastructure/**", "environments/**"]

  project_services = { for pair in flatten([
    for key, deployment in local.deployments : [
      for service in var.services : {
        key        = "${key}-${service}"
        deployment = key
        service    = service
      }
    ]
  ]) : pair.key => pair }

  workspace_variables = { for pair in flatten([
    for key, deployment in local.deployments : [
      for variable in [
        { key = "environment", value = deployment.environment, category = "terraform", description = "Environment slot this workspace deploys." },
        { key = "TFC_GCP_PROVIDER_AUTH", value = "true", category = "env", description = "Enables HCP Terraform dynamic credentials for the Google provider in this run." },
        { key = "TFC_GCP_WORKLOAD_IDENTITY_PROVIDER", value = deployment.wif_provider, category = "env", description = "Workload identity provider this run authenticates through; consumed by the Google provider." },
        { key = "TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL", value = deployment.gcp_service_account_email, category = "env", description = "Service account this run impersonates after workload identity token exchange." },
      ] : { key = "${key}-${variable.key}", workspace = key, variable = variable }
    ]
  ]) : pair.key => pair }

  trigger_pairs = {
    for i in range(1, length(var.environments)) : "ef-${var.environments[i]}-${var.name}" => "ef-${var.environments[i - 1]}-${var.name}"
  }

  status_checks = concat(
    ["ci / branch-name (pull_request)", "ci / terraform (pull_request)", "ci / yaml (pull_request)", "ci / shell (pull_request)"],
    [for name in keys(local.deployments) : "Terraform Cloud / ${name} (Predict)"],
  )
}

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

data "tfe_github_app_installation" "this" {
  name = var.github_app_installation
}

data "tfe_github_app_installation" "this" {
  name = var.github_app_installation
}

resource "github_repository" "this" {
  name        = var.repository.name
  description = var.repository.description

  visibility             = var.repository.visibility
  has_issues             = var.repository.has_issues
  has_projects           = var.repository.has_projects
  has_wiki               = var.repository.has_wiki
  allow_merge_commit     = var.repository.allow_merge_commit
  allow_squash_merge     = var.repository.allow_squash_merge
  allow_rebase_merge     = var.repository.allow_rebase_merge
  allow_auto_merge       = var.repository.allow_auto_merge
  delete_branch_on_merge = var.repository.delete_branch_on_merge

  lifecycle {
    prevent_destroy = true
  }
}

resource "github_branch_protection" "this" {
  repository_id = github_repository.this.node_id
  pattern       = var.protection.pattern

  enforce_admins                  = var.protection.enforce_admins
  allows_force_pushes             = var.protection.allows_force_pushes
  allows_deletions                = var.protection.allows_deletions
  require_conversation_resolution = var.protection.require_conversation_resolution
  required_linear_history         = var.protection.required_linear_history

  required_pull_request_reviews {
    required_approving_review_count = var.protection.required_approving_review_count
    dismiss_stale_reviews           = var.protection.dismiss_stale_reviews
  }

  required_status_checks {
    strict   = var.protection.strict_status_checks
    contexts = var.protection.status_checks
  }
}

resource "google_project" "this" {
  name            = var.name
  project_id      = var.name
  folder_id       = null
  billing_account = var.billing_account_id
  labels          = var.labels
  deletion_policy = "PREVENT"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_project_service" "apis" {
  for_each = { for s in var.services : s => s }

  service            = each.value
  project            = google_project.this.project_id
  disable_on_destroy = false
}

resource "tfe_workspace" "this" {
  name              = var.name
  project_id        = var.project_id
  working_directory = var.working_directory
  auto_apply        = var.auto_apply

  vcs_repo {
    identifier                 = "${var.github_owner}/${var.repository.name}"
    branch                     = "main"
    github_app_installation_id = data.tfe_github_app_installation.this.id
  }

  depends_on = [github_repository.this]
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

resource "tfe_variable" "gcp_impersonate_service_account" {
  key          = "GOOGLE_IMPERSONATE_SERVICE_ACCOUNT"
  value        = var.gcp_service_account_email
  category     = "env"
  workspace_id = tfe_workspace.this.id
  description  = "Service account this workspace becomes in GCP after workload identity token exchange."
}

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


resource "github_repository" "this" {
  name        = local.repository.name
  description = local.repository.description

  visibility             = local.repository.visibility
  has_issues             = local.repository.has_issues
  has_projects           = local.repository.has_projects
  has_wiki               = local.repository.has_wiki
  allow_merge_commit     = local.repository.allow_merge_commit
  allow_squash_merge     = local.repository.allow_squash_merge
  allow_rebase_merge     = local.repository.allow_rebase_merge
  allow_auto_merge       = local.repository.allow_auto_merge
  delete_branch_on_merge = local.repository.delete_branch_on_merge

  lifecycle {
    prevent_destroy = true
  }
}

resource "github_branch_protection" "this" {
  repository_id = github_repository.this.node_id
  pattern       = local.protection.pattern

  enforce_admins                  = local.protection.enforce_admins
  allows_force_pushes             = local.protection.allows_force_pushes
  allows_deletions                = local.protection.allows_deletions
  require_conversation_resolution = local.protection.require_conversation_resolution
  required_linear_history         = local.protection.required_linear_history

  required_pull_request_reviews {
    required_approving_review_count = local.protection.required_approving_review_count
    dismiss_stale_reviews           = local.protection.dismiss_stale_reviews
  }

  required_status_checks {
    strict   = local.protection.strict_status_checks
    contexts = local.protection.status_checks
  }
}


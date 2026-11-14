resource "github_repository" "registry" {
  for_each = var.repositories

  name        = each.value.name
  description = each.value.description

  visibility             = each.value.visibility
  has_issues             = each.value.has_issues
  has_projects           = each.value.has_projects
  has_wiki               = each.value.has_wiki
  allow_merge_commit     = each.value.allow_merge_commit
  allow_squash_merge     = each.value.allow_squash_merge
  allow_rebase_merge     = each.value.allow_rebase_merge
  allow_auto_merge       = each.value.allow_auto_merge
  delete_branch_on_merge = each.value.delete_branch_on_merge

  lifecycle {
    prevent_destroy = true
  }
}

resource "github_branch_protection" "main" {
  for_each = var.protections

  repository_id = github_repository.registry[each.key].node_id
  pattern       = each.value.pattern

  enforce_admins                  = each.value.enforce_admins
  allows_force_pushes             = each.value.allows_force_pushes
  allows_deletions                = each.value.allows_deletions
  require_conversation_resolution = each.value.require_conversation_resolution
  required_linear_history         = each.value.required_linear_history

  required_pull_request_reviews {
    required_approving_review_count = each.value.required_approving_review_count
    dismiss_stale_reviews           = each.value.dismiss_stale_reviews
  }

  required_status_checks {
    strict   = each.value.strict_status_checks
    contexts = each.value.status_checks
  }
}

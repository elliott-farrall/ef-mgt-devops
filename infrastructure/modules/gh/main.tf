resource "github_repository" "registry" {
  for_each = { for r in var.config.repositories : r.name => r }

  name        = each.value.name
  description = each.value.description

  visibility             = "private"
  has_issues             = true
  has_projects           = false
  has_wiki               = false
  allow_merge_commit     = false
  allow_squash_merge     = true
  allow_rebase_merge     = false
  delete_branch_on_merge = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "github_branch_protection" "main" {
  for_each = github_repository.registry

  repository_id = each.value.node_id
  pattern       = "main"

  # Code-only steady state: everything arrives through a PR with green CI —
  # including the owner. Solo account, so no human approvals are required.
  required_pull_request_reviews {
    required_approving_review_count = 0
  }

  required_status_checks {
    strict   = true
    contexts = ["ci / terraform (pull_request)"]
  }

  enforce_admins = true
}

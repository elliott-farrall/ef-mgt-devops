locals {
  repository = merge(
    { name = var.repo, description = try(var.description, "${var.repo} repository"), visibility = "private", has_issues = true, has_projects = false, has_wiki = false, allow_merge_commit = false, allow_squash_merge = true, allow_rebase_merge = false, allow_auto_merge = false, delete_branch_on_merge = true },
    var.settings,
  )
  protection = merge(
    { require_conversation_resolution = true, required_approving_review_count = 1, dismiss_stale_reviews = true, status_checks = ["ci / branch-name (pull_request)", "ci / terraform (pull_request)", "ci / yaml (pull_request)", "ci / shell (pull_request)", "Terraform Cloud / ${var.name} (Predict)"] },
    var.protection,
  )
}

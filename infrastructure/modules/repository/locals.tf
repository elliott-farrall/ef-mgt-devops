locals {
  repository = merge(
    { name = var.repo, description = try(var.description, "${var.repo} repository"), visibility = "private", has_issues = true, has_discussions = false, has_projects = false, has_wiki = false, has_downloads = false, allow_merge_commit = false, allow_squash_merge = true, allow_rebase_merge = false, allow_auto_merge = false, delete_branch_on_merge = true },
    var.settings,
  )
  protection = merge(
    { require_conversation_resolution = true, required_approving_review_count = 1, dismiss_stale_reviews = true, status_checks = var.status_checks },
    var.protection,
  )
}

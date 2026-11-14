variable "repository" {
  description = "Repository settings from locals, defaults merged."
  type = object({
    name                   = string
    description            = string
    visibility             = string
    has_issues             = bool
    has_projects           = bool
    has_wiki               = bool
    allow_merge_commit     = bool
    allow_squash_merge     = bool
    allow_rebase_merge     = bool
    allow_auto_merge       = bool
    delete_branch_on_merge = bool
  })
}

variable "protection" {
  description = "Main-branch protection policy from locals, defaults merged."
  type = object({
    pattern                         = string
    enforce_admins                  = bool
    allows_force_pushes             = bool
    allows_deletions                = bool
    require_conversation_resolution = bool
    required_linear_history         = bool
    required_approving_review_count = number
    dismiss_stale_reviews           = bool
    strict_status_checks            = bool
    status_checks                   = list(string)
  })
}

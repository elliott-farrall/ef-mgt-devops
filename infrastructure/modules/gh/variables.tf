variable "repositories" {
  description = "GitHub repositories to manage, keyed by name, with platform defaults already merged in locals."
  type = map(object({
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
  }))
}

variable "protections" {
  description = "Branch protection rules keyed by repository name, with platform defaults already merged in locals."
  type = map(object({
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
  }))

  validation {
    condition = alltrue([
      for p in values(var.protections) :
      length(p.pattern) > 0 && p.status_checks != null
    ])
    error_message = "Every protection rule needs a non-empty pattern and a status_checks list."
  }
}

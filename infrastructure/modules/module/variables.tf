variable "name" {
  description = "Module name in the registry; derived from the repository name."
  type        = string
}

variable "module_provider" {
  description = "Provider segment of the registry address; these are GCP modules."
  type        = string
  default     = "google"
}

variable "organization" {
  description = "TFC organisation hosting the registry."
  type        = string
}

variable "repository_id" {
  description = "VCS identifier, owner/repo."
  type        = string
}

variable "github_app_installation" {
  description = "Name of the TFC GitHub App installation authorised for the repository."
  type        = string
}

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

variable "name" {
  description = "Full project name; doubles as the GCP project id and the workspace name."
  type        = string
}

variable "environment" {
  description = "Environment slot injected as the terraform environment variable."
  type        = string
}

variable "project_id" {
  description = "Owning TFC project ID from module.environment."
  type        = string
}

variable "billing_account_id" {
  description = "GCP billing account to attach."
  type        = string
}

variable "labels" {
  description = "Mandatory label set."
  type        = map(string)
}

variable "services" {
  description = "GCP APIs to enable on the project."
  type        = list(string)
}

variable "working_directory" {
  description = "Terraform root inside the repository."
  type        = string
}

variable "auto_apply" {
  description = "Whether to automatically apply changes when a Terraform plan is successful."
  type        = bool
}

variable "github_owner" {
  description = "GitHub account owning the repository."
  type        = string
}

variable "github_app_installation" {
  description = "Name of the TFC GitHub App installation; resolved by data.tfe_github_app_installation within this module."
  type        = string
}

variable "wif_provider" {
  description = "Full WIF provider resource name this workspace authenticates through; exposed to runs as the WIF_PROVIDER variable."
  type        = string
}

variable "gcp_service_account_email" {
  description = "Service account the run impersonates once its workload identity token is exchanged."
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

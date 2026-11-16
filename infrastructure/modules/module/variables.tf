variable "repo" {
  description = "GitHub repository name."
  type        = string
}

variable "description" {
  description = "Repository description; defaults to the repository name."
  type        = string
  default     = null
}

variable "settings" {
  description = "Overrides for github_repository platform defaults."
  type        = any
  default     = {}
}

variable "protection" {
  description = "Overrides for the main-branch protection platform defaults."
  type        = any
  default     = {}
}

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


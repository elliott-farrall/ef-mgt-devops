variable "name" {
  description = "Module name in the registry."
  type        = string
}

variable "repository" {
  description = "VCS identifier, owner/repo."
  type        = string
}

variable "github_app_installation" {
  description = "Name of the TFC GitHub App installation authorised for the repository."
  type        = string
}

variable "organization" {
  description = "TFC organisation hosting the registry."
  type        = string
}

variable "module_provider" {
  description = "Provider segment of the registry address; these are GCP modules."
  type        = string
  default     = "google"
}

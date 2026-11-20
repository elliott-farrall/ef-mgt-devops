variable "name" {
  description = "Library name; the module in the registry."
  type        = string
}

variable "module_provider" {
  description = "Provider segment of the registry address; these are GCP modules."
  type        = string
  default     = "google"
}

variable "github_app_installation" {
  description = "Name of the TFC GitHub App installation authorised for the repository."
  type        = string
}

variable "organization" {
  description = "TFC organisation hosting the registry."
  type        = string
}

variable "description" {
  description = "Repository description."
  type        = string
  default     = null
}

variable "settings" {
  description = "Overrides for github_repository platform defaults."
  type        = any
  default     = {}
}

variable "protection" {
  description = "Overrides for the main-branch rulesets."
  type        = any
  default     = {}
}

variable "zone" {
  description = "Cloudflare zone hosting the platform DNS records."
  type        = string
}

variable "github_owner" {
  description = "GitHub account owning the repository."
  type        = string
}

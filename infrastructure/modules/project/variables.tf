variable "name" {
  description = "Project suffix; completes every generated name."
  type        = string
}

variable "environments" {
  description = "Environments the project deploys into, in rollout order."
  type        = list(string)
}

variable "repo" {
  description = "GitHub repository the project builds; created by the nested repository module."
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

variable "pages" {
  description = "Whether the repository hosts the docs site; true for the platform home."
  type        = bool
  default     = false
}

variable "cname" {
  description = "Custom domain for the Pages site; null when the repository hosts none."
  type        = string
  default     = null
}

variable "zone" {
  description = "Cloudflare zone hosting the platform DNS records."
  type        = string
}

variable "github_owner" {
  description = "GitHub account owning the repository."
  type        = string
}

variable "tfc_project_ids" {
  description = "TFC project ID hosting each environment's workspaces, keyed by environment."
  type        = map(string)
}

variable "folder_ids" {
  description = "Numeric folder ID of each environment's folder, keyed by environment."
  type        = map(string)
}

variable "wif_providers" {
  description = "Full WIF provider resource path for each environment, keyed by environment."
  type        = map(string)
}

variable "gcp_service_account_emails" {
  description = "Service account email impersonated in each environment, keyed by environment."
  type        = map(string)
}

variable "github_app_installation" {
  description = "Name of the TFC GitHub App installation; resolved by data.tfe_github_app_installation within this module."
  type        = string
}

variable "billing_account_id" {
  description = "GCP billing account attached to every deployment's project."
  type        = string
}

variable "services" {
  description = "GCP APIs enabled on every deployment's project."
  type        = list(string)
}

variable "working_directory" {
  description = "Terraform root inside the repository."
  type        = string
}


variable "landing_project_number" {
  description = "Numeric project number of the landing project hosting the workload identity pools."
  type        = string
}

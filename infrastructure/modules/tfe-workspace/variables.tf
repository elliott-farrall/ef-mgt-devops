variable "name" {
  description = "Workspace name; unique across the platform."
  type        = string
}

variable "project_id" {
  description = "Owning TFC project ID from module.tfe-project."
  type        = string
}

variable "working_directory" {
  description = "Terraform root inside the repository."
  type        = string
}

variable "auto_apply" {
  description = "Run policy."
  type        = bool
}

variable "environment" {
  description = "Environment slot injected as the terraform environment variable."
  type        = string
}

variable "repo" {
  description = "GitHub repository this workspace builds."
  type        = string
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

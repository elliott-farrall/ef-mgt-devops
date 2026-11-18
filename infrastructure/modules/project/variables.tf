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

variable "folder_id" {
  description = "Numeric ID of the environment folder hosting the project."
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

variable "queue_all_runs" {
  description = "Whether VCS pushes queue runs; false for downstream stages, whose runs come from the trigger chain."
  type        = bool
}

variable "working_directory" {
  description = "Terraform root inside the repository."
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

variable "repo" {
  description = "GitHub repository this workspace builds; created by module.repository."
  type        = string
}


# -- input name: workspace name unique across platform --
variable "name" {
  description = "Workspace name; unique across the platform."
  type        = string
}

# -- input project_id: owning TFE project ID --
variable "project_id" {
  description = "Owning TFC project ID from module.tfe-project."
  type        = string
}

# -- input working_directory: Terraform root inside repository --
variable "working_directory" {
  description = "Terraform root inside the repository."
  type        = string
}

# -- input auto_apply: run policy --
variable "auto_apply" {
  description = "Whether to automatically apply changes when a Terraform plan is successful."
  type        = bool
}

# -- input environment: env slot injected as terraform env var --
variable "environment" {
  description = "Environment slot injected as the terraform environment variable."
  type        = string
}

# -- input repo: GitHub repository this workspace builds --
variable "repo" {
  description = "GitHub repository this workspace builds."
  type        = string
}

# -- input github_owner: GitHub account owning the repository --
variable "github_owner" {
  description = "GitHub account owning the repository."
  type        = string
}

# -- input github_app_installation: TFC GitHub App installation name --
variable "github_app_installation" {
  description = "Name of the TFC GitHub App installation; resolved by data.tfe_github_app_installation within this module."
  type        = string
}

# -- input wif_provider: full WIF provider resource name exposed to runs --
variable "wif_provider" {
  description = "Full WIF provider resource name this workspace authenticates through; exposed to runs as the WIF_PROVIDER variable."
  type        = string
}

# -- input gcp_service_account_email: SA impersonated after WIF token exchange --
variable "gcp_service_account_email" {
  description = "Service account the run impersonates once its workload identity token is exchanged."
  type        = string
}

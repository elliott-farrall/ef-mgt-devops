variable "name" {
  description = "Workspace name; also the repository it links to."
  type        = string
}

variable "project_id" {
  description = "Owning TFC project ID from module.tfc-project."
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

variable "github_owner" {
  description = "GitHub account owning the repository."
  type        = string
}

variable "github_app_installation_id" {
  description = "TFC GitHub App installation ID (prerequisite); links the workspace to its repository."
  type        = string
}

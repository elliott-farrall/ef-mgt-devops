variable "name" {
  description = "Workspace name."
  type        = string
}

variable "organization" {
  description = "TFC organization handle."
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

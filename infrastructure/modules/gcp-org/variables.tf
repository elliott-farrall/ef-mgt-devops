variable "folders" {
  description = "Folder nodes keyed by name with their parent folder (\"\" = organisation root). Derived from the nested tree in locals.tf."
  type = map(object({
    parent = string
  }))
}

variable "projects" {
  description = "Project nodes keyed by project ID with their parent folder. Derived from the nested tree in locals.tf."
  type = map(object({
    parent = string
  }))
}

variable "organisation_id" {
  description = "Numeric GCP organisation ID."
  type        = string
}

variable "billing_account" {
  description = "Billing account to attach to created projects."
  type        = string
}

variable "labels" {
  description = "Mandatory label set applied to created projects."
  type        = map(string)
  default     = {}
}

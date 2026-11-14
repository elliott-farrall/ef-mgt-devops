variable "role" {
  description = "IAM role to bind."
  type        = string
}

variable "member" {
  description = "Member, e.g. serviceAccount:<email>."
  type        = string
}

variable "folder" {
  description = "Folder resource name (folders/<ID>) when the scope is a folder."
  type        = string
  default     = null
}

variable "project" {
  description = "Project ID when the scope is a project."
  type        = string
  default     = null
}

variable "organisation" {
  description = "Organisation ID when the scope is the organisation."
  type        = string
  default     = null
}

variable "billing_account" {
  description = "Billing account ID when the scope is billing."
  type        = string
  default     = null
}

variable "name" {
  description = "Project ID (globally unique)."
  type        = string
}

variable "folder_id" {
  description = "Numeric parent folder ID from module.gcp-folder."
  type        = string
}

variable "billing_account_id" {
  description = "Billing account to attach."
  type        = string
}

variable "labels" {
  description = "Mandatory label set."
  type        = map(string)
  default     = {}
}

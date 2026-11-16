variable "name" {
  description = "Project ID (globally unique)."
  type        = string
}

variable "folder_id" {
  description = "Numeric parent folder ID, or null to place the project directly under the organisation root."
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

variable "services" {
  description = "List of GCP APIs to enable for this project."
  type        = list(string)
  default     = []
}

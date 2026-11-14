variable "name" {
  description = "Budget display name."
  type        = string
}

variable "billing_account_id" {
  description = "Billing account ID from root data source."
  type        = string
}

variable "currency" {
  description = "ISO 4217 currency code."
  type        = string
}

variable "amount" {
  description = "Monthly spend limit in whole currency units."
  type        = number
}

variable "thresholds" {
  description = "Alert fractions of the amount."
  type        = list(number)
}

variable "projects" {
  description = "Project IDs to scope the budget to; empty means the whole account."
  type        = list(string)
  default     = []
}

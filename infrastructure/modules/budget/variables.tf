variable "name" {
  description = "Budget display name."
  type        = string
}

variable "billing_account_id" {
  description = "Billing account ID the budget belongs to."
  type        = string
}

variable "amount" {
  description = "Monthly spend alert threshold in whole GBP."
  type        = number
}

variable "thresholds" {
  description = "Alert fractions of the amount."
  type        = list(number)
}

variable "scope" {
  description = "Budget coverage: empty for the whole account, or a resolved ancestor path — projects/<id>, folders/<ID>, organizations/<ID>."
  type        = string
  default     = ""

  validation {
    condition     = var.scope == "" || can(regex("^(projects/ef-[a-z0-9-]+|folders/ef-[a-z0-9-]+|organizations/[0-9]+)$", var.scope))
    error_message = "scope must be empty or a resolved ancestor path: projects/, folders/, or organizations/."
  }
}

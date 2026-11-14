variable "scope" {
  description = "Binding target as a resolved ancestor path: folders/<ID>, projects/<id>, organizations/<ID>, or billingAccounts/<ID>."
  type        = string

  validation {
    condition     = can(regex("^(folders|projects|organizations|billingAccounts)/.+$", var.scope))
    error_message = "scope must be a resolved ancestor path: folders/, projects/, organizations/, or billingAccounts/."
  }
}

variable "role" {
  description = "IAM role to bind."
  type        = string
}

variable "member" {
  description = "Member, e.g. serviceAccount:<email>."
  type        = string
}

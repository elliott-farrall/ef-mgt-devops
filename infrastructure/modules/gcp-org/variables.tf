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

variable "organisation" {
  description = "Domain the GCP organisation is registered under; resolved via data.google_organization."
  type        = string
}

variable "billing" {
  description = "Billing account name, currency, and budget alert registry from gcp.billing."
  type = object({
    name     = string
    currency = string
    budgets = list(object({
      name       = string
      amount     = number
      thresholds = list(number)
      projects   = optional(list(string), [])
    }))
  })
}

variable "iam" {
  description = "Platform identities with their hosting project and IAM bindings, from gcp.iam."
  type = list(object({
    name    = string
    project = string
    bindings = list(object({
      scope = string
      roles = list(string)
    }))
  }))
}

variable "labels" {
  description = "Mandatory label set applied to created projects."
  type        = map(string)
  default     = {}
}

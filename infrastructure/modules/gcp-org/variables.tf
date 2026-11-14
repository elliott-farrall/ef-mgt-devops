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
  description = "Billing account display name; resolved via data.google_billing_account."
  type        = string
}

variable "landing_project" {
  description = "Project that hosts every platform service account."
  type        = string
}

variable "service_accounts" {
  description = "Platform identities with their bindings; scopes derived from tree placement in locals.tf."
  type = list(object({
    name = string
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

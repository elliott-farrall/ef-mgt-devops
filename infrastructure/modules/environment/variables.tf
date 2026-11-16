variable "name" {
  description = "Environment name; every derived resource carries it."
  type        = string
}

variable "organization_id" {
  description = "GCP organisation ID hosting the platform."
  type        = string
}

variable "billing_account_id" {
  description = "GCP billing account ID granted to the environment identity."
  type        = string
}

variable "landing_project_id" {
  description = "Project hosting the identity, pool, provider, and its bindings."
  type        = string
}

variable "pool_project_number" {
  description = "Numeric ID of the landing project; builds the pool principalSet member."
  type        = string
}

variable "issuer" {
  description = "OIDC issuer URI of the Terraform Cloud API endpoint."
  type        = string
}

variable "roles" {
  description = "Role bindings for the environment identity, scoped by target kind: organization, billing, or project:<id>."
  type = list(object({
    scope = string
    role  = string
  }))
}

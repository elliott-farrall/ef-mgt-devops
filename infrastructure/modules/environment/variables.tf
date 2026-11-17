variable "name" {
  description = "Environment name; every derived resource carries it."
  type        = string
}

variable "organization_id" {
  description = "GCP organisation ID hosting the platform."
  type        = string
}

variable "folder_parent" {
  description = "Resource name of the folder parent: organizations/<id> or folders/<id>."
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

variable "issuer" {
  description = "OIDC issuer URI of the Terraform Cloud API endpoint."
  type        = string
}

variable "folder_roles" {
  description = "Roles the environment identity holds on its own folder; grants project creation inside it."
  type        = list(string)
}

variable "landing_roles" {
  description = "Roles the environment identity holds on the landing project."
  type        = list(string)
}

variable "platform_roles" {
  description = "Scoped role pairs for platform duties: organization, billing, or project:<id>."
  type = list(object({
    scope = string
    role  = string
  }))
  default = []
}

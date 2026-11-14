variable "name" {
  description = "Provider id (tfc-<environment> convention)."
  type        = string
}

variable "pool" {
  description = "Workload identity pool id."
  type        = string
}

variable "project" {
  description = "Project owning the pool."
  type        = string
}

variable "pool_project_number" {
  description = "Numeric project ID for principal URIs."
  type        = string
}

variable "issuer" {
  description = "OIDC issuer this provider trusts."
  type        = string
}

variable "service_account_email" {
  description = "Service account this identity authenticates as."
  type        = string
}

variable "environment" {
  description = "Environment name stamped onto admitted tokens as attribute.environment."
  type        = string
}

variable "attribute_condition" {
  description = "CEL condition restricting which TFC tokens the provider accepts."
  type        = string
}

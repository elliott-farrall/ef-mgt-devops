variable "name" {
  description = "Service account name."
  type        = string
}

variable "project" {
  description = "Hosting project ID."
  type        = string
}

variable "pool" {
  description = "Workload identity pool id."
  type        = string
}

variable "pool_project_number" {
  description = "Numeric project ID owning the pool, for principal URIs."
  type        = string
}

variable "provider_name" {
  description = "WIF provider bound to this identity."
  type        = string
}

variable "attribute_condition" {
  description = "CEL condition restricting which TFC tokens the provider accepts."
  type        = string
}

variable "subject" {
  description = "Token subject mapped to this service account."
  type        = string
}

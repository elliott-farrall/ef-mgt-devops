variable "name" {
  description = "Managed zone resource name."
  type        = string
}

variable "domain" {
  description = "DNS domain, e.g. elliott-farrall.phd."
  type        = string
}

variable "project_id" {
  description = "Project hosting the zone."
  type        = string
}

variable "records" {
  description = "Platform-owned record sets: { name, type, ttl, records }."
  type = list(object({
    name    = string
    type    = string
    ttl     = number
    records = list(string)
  }))
  default = []
}

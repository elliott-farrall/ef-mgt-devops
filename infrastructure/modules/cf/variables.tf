variable "account" {
  description = "Cloudflare account display name; resolved via data.cloudflare_accounts."
  type        = string
}

variable "zones" {
  description = "Zone entries keyed by name with defaults applied in locals.tf."
  type = map(object({
    name = string
    plan = string
  }))
}

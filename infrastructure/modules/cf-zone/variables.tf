variable "account_id" {
  description = "Cloudflare account ID from root data source."
  type        = string
}

variable "zone" {
  description = "Zone name."
  type        = string
}

variable "plan" {
  description = "Cloudflare zone plan."
  type        = string
}

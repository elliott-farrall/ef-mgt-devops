variable "zone" {
  description = "Cloudflare zone name hosting the record; resolved to its identifier by data.cloudflare_zone."
  type        = string
}

variable "name" {
  description = "Record name."
  type        = string
}

variable "type" {
  description = "Record type."
  type        = string
}

variable "content" {
  description = "Record value."
  type        = string
}

variable "priority" {
  description = "Record priority; MX records require it."
  type        = number
  default     = null
}

variable "ttl" {
  description = "Record TTL in seconds."
  type        = number
  default     = 300
}

variable "proxied" {
  description = "Whether Cloudflare proxies the record."
  type        = bool
  default     = false
}

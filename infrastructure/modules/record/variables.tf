variable "zone_id" {
  description = "Cloudflare zone identifier hosting the record; resolved at the root so it is known at plan time."
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

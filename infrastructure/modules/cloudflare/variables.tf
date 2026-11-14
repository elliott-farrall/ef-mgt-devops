variable "config" {
  type        = map(any)
  description = "Merged environment config map."
}

variable "labels" {
  type        = map(string)
  description = "Mandatory label set (reserved for parity; Cloudflare zones take no labels)."
}

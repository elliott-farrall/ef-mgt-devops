variable "config" {
  type        = map(any)
  description = "Platform config namespace from environments/<name>/<file>.yaml, passed as a locals slice."
}

variable "labels" {
  type        = map(string)
  description = "Mandatory label set (tag-equivalents applied to TFC resources where supported)."
}

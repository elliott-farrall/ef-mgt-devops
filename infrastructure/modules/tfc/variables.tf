variable "config" {
  type        = map(any)
  description = "Merged environment config map."
}

variable "labels" {
  type        = map(string)
  description = "Mandatory label set (tag-equivalents applied to TFC resources where supported)."
}

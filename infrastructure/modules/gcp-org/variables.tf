variable "config" {
  type        = map(any)
  description = "Merged environment config map (consumed via derived locals in the root stack)."
}

variable "labels" {
  type        = map(string)
  description = "Mandatory label set applied to every resource."
}

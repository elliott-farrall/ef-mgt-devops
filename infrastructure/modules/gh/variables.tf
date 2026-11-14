variable "config" {
  type        = map(any)
  description = "Platform config namespace from environments/<name>/<file>.yaml, passed as a locals slice."
}

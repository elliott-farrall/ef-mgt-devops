variable "name" {
  description = "Folder display name."
  type        = string
}

variable "parent" {
  description = "Parent resource: organizations/<ID> or folders/<ID>."
  type        = string
}

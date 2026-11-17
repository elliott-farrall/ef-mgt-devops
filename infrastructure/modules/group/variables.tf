variable "name" {
  description = "Group name; the folder is ef-<name>."
  type        = string
}

variable "organization_id" {
  description = "GCP organisation ID hosting the group folder."
  type        = string
}

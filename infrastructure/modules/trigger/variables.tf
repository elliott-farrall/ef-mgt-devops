variable "workspace_id" {
  description = "Workspace whose runs are queued when the source completes."
  type        = string
}

variable "sourceable_id" {
  description = "Workspace whose successful runs trigger this workspace."
  type        = string
}

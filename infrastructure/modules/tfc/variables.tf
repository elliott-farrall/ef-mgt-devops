variable "organisation" {
  description = "TFC organisation handle."
  type        = string
}

variable "projects" {
  description = "Plane project names, derived from the tfc.projects registry in locals.tf."
  type        = list(string)
}

variable "workspaces" {
  description = "Workspace nodes keyed by name with their owning project, derived from the nested registry in locals.tf."
  type = map(object({
    name              = string
    project           = string
    repo              = string
    working_directory = string
    auto_apply        = bool
  }))

  validation {
    condition = alltrue([
      for w in values(var.workspaces) :
      contains(var.projects, w.project)
    ])
    error_message = "Every workspace must name an existing project as its parent."
  }
}

variable "tree" {
  description = "The whole folder tree: organisation root resource name plus flat nodes keyed by name with their parent (root marks organisation-root children)."
  type = object({
    root_parent = string
    folders = map(object({
      parent = string
    }))
  })
}

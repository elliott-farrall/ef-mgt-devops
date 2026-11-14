variable "tree" {
  description = "The whole folder tree: organisation root resource name plus flat nodes keyed by name with their parent (\"\" = root)."
  type = object({
    root_parent = string
    folders = map(object({
      parent = string
    }))
  })
}

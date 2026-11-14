check "parent_references" {
  assert {
    condition     = alltrue([for f in values(var.tree.folders) : f.parent == "" || contains(keys(var.tree.folders), f.parent)])
    error_message = "Every folder parent must be empty (organisation root) or another key in the folders map."
  }
}

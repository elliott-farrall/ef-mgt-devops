# -- check parent_references: folder parents must be root or another declared folder --
check "parent_references" {
  assert {
    condition     = alltrue([for f in values(var.tree.folders) : f.parent == "root" || contains(keys(var.tree.folders), f.parent)])
    error_message = "Every folder parent must be root or another key in the folders map."
  }
}

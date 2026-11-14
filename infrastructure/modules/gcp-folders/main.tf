resource "google_folder" "tree" {
  for_each = var.tree.folders

  display_name = each.key
  parent       = each.value.parent == "" ? var.tree.root_parent : google_folder.tree[each.value.parent].name

  lifecycle {
    prevent_destroy = true
  }
}

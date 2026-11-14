resource "google_folder" "tree" {
  for_each = var.folders

  display_name = each.key
  parent       = each.value.parent == "" ? "organizations/${var.organisation_id}" : google_folder.tree[each.value.parent].name

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_project" "platform" {
  for_each = var.projects

  name            = each.key
  project_id      = each.key
  folder_id       = google_folder.tree[each.value.parent].folder_id
  billing_account = var.billing_account
  labels          = var.labels

  deletion_policy = "PREVENT"

  lifecycle {
    prevent_destroy = true
  }
}

# TODO (bootstrap prep): service accounts (sa-mgt-tfc, sa-adm-bootstrap),
# workload identity pool + OIDC providers, org policies (prevent project
# deletion, required labels, allowed regions), folder-level IAM bindings.

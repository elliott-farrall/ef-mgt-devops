resource "google_folder" "ef_root" {
  display_name = "ef-root"
  parent       = "organizations/${var.config.organization_id}"
}

resource "google_folder" "tree" {
  for_each = { for f in var.config.folders : f.name => f }

  display_name = each.value.name
  parent       = each.value.parent == "root" ? google_folder.ef_root.name : google_folder.tree[each.value.parent].name

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_project" "platform" {
  for_each = { for p in var.config.projects : p.id => p }

  name            = each.value.id
  project_id      = each.value.id
  folder_id       = google_folder.tree[each.value.folder].folder_id
  billing_account = var.config.billing_account
  labels          = var.labels

  deletion_policy = "PREVENT"

  lifecycle {
    prevent_destroy = true
  }
}

# TODO (bootstrap prep): service accounts (sa-mgt-tfc, sa-adm-bootstrap),
# workload identity pool + OIDC providers, org policies (prevent project
# deletion, required labels, allowed regions), folder-level IAM bindings.

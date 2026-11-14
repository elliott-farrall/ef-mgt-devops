# GCP organisation structure: root folder, the ef-mgt/ef-hub/ef-app plane
# folders, the ef-dev/ef-pre/ef-prd ladder, and the landing project.
# Everything here is created by scripts/bootstrap/01-gcp.sh first and adopted
# via terraform import (see docs/bootstrap.md).

resource "google_folder" "ef_root" {
  display_name = "ef-root"
  parent       = "organizations/${var.config.organization_id}"
}

resource "google_folder" "tree" {
  for_each = var.config.folders

  display_name = each.value.name
  parent       = each.value.parent == "root" ? google_folder.ef_root.name : google_folder.tree[each.value.parent].name

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_project" "landing" {
  name            = var.config.landing_project
  project_id      = var.config.landing_project
  folder_id       = google_folder.tree["ef-mgt"].folder_id
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

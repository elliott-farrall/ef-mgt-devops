resource "google_project" "this" {
  name            = var.name
  project_id      = var.name
  folder_id       = var.folder_id
  billing_account = var.billing_account_id
  labels          = var.labels

  deletion_policy = "PREVENT"

  lifecycle {
    prevent_destroy = true
  }
}

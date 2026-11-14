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

resource "google_project_service" "apis" {
  for_each = { for s in var.services : s => s }

  service            = each.value
  project            = google_project.this.project_id
  disable_on_destroy = false
}

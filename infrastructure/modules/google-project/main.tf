# -- google_project.this: GCP project with identity pool hosting role --
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

# -- google_project_service.apis: APIs enabled on the project --
resource "google_project_service" "apis" {
  for_each = { for s in var.services : s => s }

  service            = each.value
  project            = google_project.this.project_id
  disable_on_destroy = false
}

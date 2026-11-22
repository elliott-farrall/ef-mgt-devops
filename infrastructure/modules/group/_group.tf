resource "google_folder" "this" {
  display_name = "ef-${var.name}"
  parent       = var.organization_id

  lifecycle {
    prevent_destroy = true
  }
}

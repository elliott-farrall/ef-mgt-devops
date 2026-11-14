# -- google_service_account.this: TFC integration service account --
resource "google_service_account" "this" {
  account_id   = var.name
  display_name = var.name
  project      = var.project
}

data "google_billing_account" "this" {
  billing_account = local.config.organisation.gcp.billing
}

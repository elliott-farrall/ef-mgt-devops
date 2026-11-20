data "google_organization" "this" {
  domain = local.config.organisation.gcp.domain
}

data "google_billing_account" "this" {
  display_name = local.config.organisation.gcp.billing
}

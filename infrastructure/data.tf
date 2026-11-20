data "google_organization" "this" {
  domain = local.config.organisation.gcp.domain
}

data "google_billing_account" "this" {
  billing_account = local.config.organisation.gcp.billing
}

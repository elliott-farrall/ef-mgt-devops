data "google_organization" "ef" {
  domain = local.config.organisation.gcp.domain
}

data "google_billing_account" "ef" {
  display_name = local.config.organisation.gcp.billing.name
}


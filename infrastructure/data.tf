# -- data.google_organization: looks up GCP organisation by domain --
data "google_organization" "ef" {
  domain = local.config.organisation.gcp.domain
}

# -- data.google_billing_account: locates the billing account named in config --
data "google_billing_account" "ef" {
  display_name = local.config.organisation.gcp.billing
}

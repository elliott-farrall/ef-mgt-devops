# -- data.google_organization: looks up GCP organisation by domain --
data "google_organization" "ef" {
  domain = local.config.organisation.gcp.domain
}

# -- data.google_billing_account: locates the billing account named in config --
data "google_billing_account" "ef" {
  display_name = "ef-${local.config.organisation.gcp.billing.name}"
}

# -- data.google_project.landing: numeric ID of the platform home --
data "google_project" "landing" {
  project_id = local.google_default_project
}

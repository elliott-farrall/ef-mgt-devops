data "google_organization" "ef" {
  domain = local.config.gcp.organisation
}

data "google_billing_account" "ef" {
  display_name = local.config.gcp.billing.name
}

data "tfe_github_app_installation" "ef" {
  name = local.config.tfc.github_app_installation
}


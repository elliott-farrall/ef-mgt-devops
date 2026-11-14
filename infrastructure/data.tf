data "google_organization" "ef" {
  domain = local.config.gcp.organisation
}

data "google_billing_account" "ef" {
  display_name = local.config.gcp.billing.name
}

data "cloudflare_accounts" "ef" {
  name = local.config.cf.account
}

data "tfe_organization" "ef" {
  name = local.config.tfc.organisation
}

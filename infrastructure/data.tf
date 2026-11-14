data "google_organization" "ef" {
  domain = local.gcp.organisation
}

data "google_billing_account" "ef" {
  display_name = local.gcp.billing.name
}

data "cloudflare_accounts" "ef" {
  name = local.cf.account
}

data "tfe_organization" "ef" {
  name = local.tfc.organisation
}

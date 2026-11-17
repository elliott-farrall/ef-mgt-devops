data "google_organization" "ef" {
  domain = local.config.organisation.gcp.domain
}

data "cloudflare_zone" "ef" {
  filter = {
    name = local.config.organisation.gcp.domain
  }
}

data "google_billing_account" "ef" {
  display_name = local.config.organisation.gcp.billing
}

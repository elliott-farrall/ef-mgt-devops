data "google_organization" "this" {
  domain = local.config.organisation.gcp.domain
}

data "google_billing_account" "this" {
  billing_account = local.config.organisation.gcp.billing
}

data "cloudflare_zone" "zones" {
  for_each = toset([for r in local.records : r.zone])

  filter = {
    name = each.value
  }
}

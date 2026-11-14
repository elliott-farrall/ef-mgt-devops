# Composition only: locals + module calls. No hand-written resource blocks
# beyond trivial glue — resources live in infrastructure/modules/.

module "gcp_org" {
  source = "./modules/gcp-org"
  config = local.config
  labels = local.labels
}

module "tfc" {
  source = "./modules/tfc"
  config = local.config
  labels = local.labels
}

module "cloudflare" {
  source = "./modules/cloudflare"
  config = local.config
  labels = local.labels
}

# Fail at plan time if bootstrap placeholders were never filled in.
check "config_placeholders" {
  assert {
    condition = alltrue([
      for k in ["organization_id", "billing_account", "cf_account_id"] :
      !strcontains(lower(tostring(local.config[k])), "replace_me")
    ])
    error_message = "environments/${var.environment}/ still contains REPLACE_ME placeholders — fill in real IDs before planning."
  }
}

module "gcp_org" {
  source = "./modules/gcp-org"
  config = local.gcp
  labels = local.labels
}

module "tfc" {
  source = "./modules/tfc"
  config = local.tfc
  labels = local.labels
}

module "cf" {
  source = "./modules/cf"
  config = local.cf
  labels = local.labels
}

module "gh" {
  source = "./modules/gh"
  config = local.gh
}

check "config_placeholders" {
  assert {
    condition = alltrue([
      for v in [local.gcp.organization_id, local.gcp.billing_account, local.cf.account_id] :
      !strcontains(lower(tostring(v)), "replace_me")
    ])
    error_message = "environments/${var.environment}/ still contains REPLACE_ME placeholders — fill in real IDs before planning."
  }
}

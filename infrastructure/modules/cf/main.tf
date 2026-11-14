data "cloudflare_accounts" "ef" {
  name = var.account
}

resource "cloudflare_zone" "registry" {
  for_each = var.zones

  account_id = data.cloudflare_accounts.ef.accounts[0].id
  zone       = each.value.name
  plan       = each.value.plan

  lifecycle {
    precondition {
      condition     = length(data.cloudflare_accounts.ef.accounts) == 1
      error_message = "cf.account '${var.account}' must match exactly one Cloudflare account."
    }
  }
}

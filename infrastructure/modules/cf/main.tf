resource "cloudflare_zone" "registry" {
  for_each = { for z in var.config.zones : z.name => z }

  account_id = var.config.account_id
  zone       = each.value.name
  plan       = each.value.plan
}

# TODO (bootstrap prep): zone settings (TLS, minify); scoped API token
# rotation story; NS-check wait lives in the seed script.

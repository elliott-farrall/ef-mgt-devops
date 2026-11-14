# Cloudflare: the apex zone — the only DNS concern at launch. Created by
# scripts/bootstrap/03-cloudflare.sh and adopted via import.

resource "cloudflare_zone" "apex" {
  account_id = var.config.cf_account_id
  zone       = var.config.cf_apex_zone
  plan       = "free"
}

# TODO (bootstrap prep): zone settings (TLS, minify), scoped API token
# rotation story, NS-check wait handled by the seed script.

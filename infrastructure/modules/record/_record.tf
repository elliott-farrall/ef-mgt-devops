resource "cloudflare_dns_record" "this" {
  zone_id  = data.cloudflare_zone.this.id
  name     = var.name
  type     = var.type
  content  = var.content
  ttl      = var.ttl
  proxied  = var.proxied
  priority = var.priority
}

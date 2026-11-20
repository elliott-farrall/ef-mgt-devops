resource "cloudflare_dns_record" "this" {
  zone_id = var.zone_id
  name    = var.name
  type    = var.type
  content = var.content
  ttl     = var.ttl

  proxied  = var.proxied
  priority = var.priority

  lifecycle {
    create_before_destroy = true
  }
}

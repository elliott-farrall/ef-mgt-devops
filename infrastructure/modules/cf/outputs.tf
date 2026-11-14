output "zone_ids" {
  description = "Zone IDs keyed by zone name."
  value       = { for k, z in cloudflare_zone.registry : k => z.id }
}

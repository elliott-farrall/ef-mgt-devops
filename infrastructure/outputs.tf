output "zone_name_servers" {
  description = "Cloud DNS assigned name servers per zone; set as NS records at the registrar to delegate."
  value       = { for key, zone in module.zone : key => zone.google_dns_managed_zone.this.name_servers }
}

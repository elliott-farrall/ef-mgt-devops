output "nameservers" {
  description = "Nameserver delegation set for the zone."
  value       = google_dns_managed_zone.this.name_servers
}

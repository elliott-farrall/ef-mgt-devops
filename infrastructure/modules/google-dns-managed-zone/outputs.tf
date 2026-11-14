output "google_dns_managed_zone" {
  description = "The managed zone resource."
  value       = google_dns_managed_zone.this
}

output "google_dns_record_set" {
  description = "DNS records within the zone."
  value       = google_dns_record_set.this
}

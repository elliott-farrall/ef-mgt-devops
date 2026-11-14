output "google_project" {
  description = "The GCP project resource."
  value       = google_project.this
}

output "google_project_service" {
  description = "Map of enabled GCP APIs keyed by service name."
  value       = google_project_service.apis
}

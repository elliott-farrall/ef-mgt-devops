output "google_project" {
  value = google_project.this
}

output "google_project_service" {
  description = "Map of enabled GCP APIs keyed by service name."
  value       = google_project_service.apis
}

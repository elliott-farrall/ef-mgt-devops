output "github_repository" {
  description = "The GitHub repository resource."
  value       = github_repository.this
}

output "google_project" {
  description = "The GCP project resource."
  value       = google_project.this
}

output "google_project_service" {
  description = "Map of enabled GCP APIs keyed by service name."
  value       = google_project_service.apis
}

output "tfe_workspace" {
  description = "The TFC workspace resource."
  value       = tfe_workspace.this
}

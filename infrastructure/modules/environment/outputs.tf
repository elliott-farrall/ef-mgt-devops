output "tfe_project" {
  description = "The TFC project resource."
  value       = tfe_project.this
}

output "google_service_account" {
  description = "The environment service account resource."
  value       = google_service_account.this
}

output "google_iam_workload_identity_pool" {
  description = "The workload identity pool resource."
  value       = google_iam_workload_identity_pool.this
}

output "google_iam_workload_identity_pool_provider" {
  description = "The workload identity pool provider resource."
  value       = google_iam_workload_identity_pool_provider.this
}

output "google_folder" {
  description = "The environment folder resource."
  value       = google_folder.this
}

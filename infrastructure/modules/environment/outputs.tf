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

output "project_number" {
  description = "Numeric project number of the landing project hosting the pool."
  value       = var.landing_project_number
}

output "workload_identity_pool_id" {
  description = "Pool identifier of the environment workload identity pool."
  value       = google_iam_workload_identity_pool.this.workload_identity_pool_id
}

output "workload_identity_pool_provider_id" {
  description = "Provider identifier of the environment workload identity pool provider."
  value       = google_iam_workload_identity_pool_provider.this.workload_identity_pool_provider_id
}

output "google_iam_workload_identity_pool_provider" {
  description = "The OIDC provider resource."
  value       = google_iam_workload_identity_pool_provider.this
}

output "google_service_account_iam_member" {
  description = "SA IAM binding for workload identity."
  value       = google_service_account_iam_member.this
}

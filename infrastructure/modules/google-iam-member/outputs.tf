output "google_folder_iam_member" {
  description = "Folder IAM bindings."
  value       = google_folder_iam_member.this
}

output "google_project_iam_member" {
  description = "Project IAM bindings."
  value       = google_project_iam_member.this
}

output "google_organization_iam_member" {
  description = "Organization IAM bindings."
  value       = google_organization_iam_member.this
}

output "google_billing_account_iam_member" {
  description = "Billing account IAM bindings."
  value       = google_billing_account_iam_member.this
}

resource "google_iam_workload_identity_pool_provider" "this" {
  workload_identity_pool_id          = var.pool
  workload_identity_pool_provider_id = var.name
  project                            = var.project
  attribute_condition                = var.attribute_condition

  oidc {
    issuer_uri = var.issuer
  }
}

resource "google_service_account_iam_member" "this" {
  service_account_id = "projects/${var.project}/serviceAccounts/${var.service_account_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/projects/${var.pool_project_number}/locations/global/workloadIdentityPools/${var.pool}/subject/${var.subject}"
}

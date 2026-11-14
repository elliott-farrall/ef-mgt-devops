# -- google_iam_workload_identity_pool_provider.this: OIDC provider for TFC in WIF pool --
resource "google_iam_workload_identity_pool_provider" "this" {
  workload_identity_pool_id          = var.pool
  workload_identity_pool_provider_id = var.name
  project                            = var.project
  attribute_condition                = var.attribute_condition
  attribute_mapping = {
    "attribute.environment" = "\"${var.environment}\""
  }

  oidc {
    issuer_uri = var.issuer
  }
}

# -- google_service_account_iam_member.this: grants the pool permission to impersonate the SA --
resource "google_service_account_iam_member" "this" {
  service_account_id = "projects/${var.project}/serviceAccounts/${var.service_account_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${var.pool_project_number}/locations/global/workloadIdentityPools/${var.pool}/attribute.environment/${var.environment}"
}

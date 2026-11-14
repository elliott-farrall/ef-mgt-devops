resource "google_service_account" "this" {
  account_id   = var.name
  display_name = var.name
  project      = var.project
}

resource "google_iam_workload_identity_pool_provider" "this" {
  workload_identity_pool_id          = var.pool
  workload_identity_pool_provider_id = var.provider_name
  project                            = var.project
  attribute_condition                = var.attribute_condition

  oidc {
    issuer_uri = "https://app.terraform.io"
  }
}

resource "google_service_account_iam_member" "this" {
  service_account_id = "projects/${var.project}/serviceAccounts/${google_service_account.this.email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/projects/${var.pool_project_number}/locations/global/workloadIdentityPools/${var.pool}/subject/${var.subject}"
}

resource "google_folder" "this" {
  display_name = "ef-${var.name}"
  parent       = "organizations/${var.organization_id}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_service_account" "this" {
  account_id   = "sa-${var.name}-tfc"
  display_name = "sa-${var.name}-tfc"
  project      = var.landing_project_id
}

resource "google_iam_workload_identity_pool" "this" {
  workload_identity_pool_id = "ef-${var.name}-tfc"
  project                   = var.landing_project_id
}

resource "google_iam_workload_identity_pool_provider" "this" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.this.workload_identity_pool_id
  workload_identity_pool_provider_id = "tfc-${var.name}"
  project                            = var.landing_project_id

  attribute_condition = "assertion.workspace_name.startsWith(\"ef-${var.name}-\")"
  attribute_mapping = {
    "attribute.environment" = "\"${var.name}\""
  }

  oidc {
    issuer_uri = var.issuer
  }
}

resource "google_service_account_iam_member" "this" {
  service_account_id = google_service_account.this.id
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.this.name}/attribute.environment/${var.name}"
}

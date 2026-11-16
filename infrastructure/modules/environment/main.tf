resource "tfe_project" "this" {
  name = "ef-${var.name}"
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
  member             = "principalSet://iam.googleapis.com/projects/${var.pool_project_number}/locations/global/workloadIdentityPools/ef-${var.name}-tfc/attribute.environment/${var.name}"
}

locals {
  project_roles      = { for r in var.roles : r.role => r if startswith(r.scope, "project:") }
  organization_roles = { for r in var.roles : r.role => r if r.scope == "organization" }
  billing_roles      = { for r in var.roles : r.role => r if r.scope == "billing" }
}

resource "google_project_iam_member" "this" {
  for_each = local.project_roles

  project = trimprefix(each.value.scope, "project:")
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.this.email}"
}

resource "google_organization_iam_member" "this" {
  for_each = local.organization_roles

  org_id = var.organization_id
  role   = each.value.role
  member = "serviceAccount:${google_service_account.this.email}"
}

resource "google_billing_account_iam_member" "this" {
  for_each = local.billing_roles

  billing_account_id = var.billing_account_id
  role               = each.value.role
  member             = "serviceAccount:${google_service_account.this.email}"
}

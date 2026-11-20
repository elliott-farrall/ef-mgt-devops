locals {
  folder_roles  = ["roles/resourcemanager.projectCreator", "roles/editor"]
  landing_roles = ["roles/iam.serviceAccountUser", "roles/dns.admin"]
  platform_pairs = var.name == "mgt" ? { for pair in [
    { scope = "organization", role = "roles/resourcemanager.organizationAdmin" },
    { scope = "billing", role = "roles/billing.costsManager" },
    { scope = "project:${var.landing_project_id}", role = "roles/resourcemanager.projectOwner" },
  ] : pair.role => pair } : {}

  folder_scopes  = { for role in local.folder_roles : role => google_folder.this.name }
  landing_scopes = { for role in local.landing_roles : role => var.landing_project_id }
  project_pairs = merge(
    { for role in local.landing_roles : role => var.landing_project_id },
    { for pair in local.platform_pairs : pair.role => trimprefix(pair.scope, "project:") if startswith(pair.scope, "project:") },
  )
}

resource "google_folder_iam_member" "this" {
  for_each = local.folder_scopes

  folder = each.value
  role   = each.key
  member = "serviceAccount:${google_service_account.this.email}"
}

resource "google_project_iam_member" "this" {
  for_each = local.project_pairs

  project = each.value
  role    = each.key
  member  = "serviceAccount:${google_service_account.this.email}"
}

resource "google_organization_iam_member" "this" {
  for_each = { for pair in local.platform_pairs : pair.role => pair if pair.scope == "organization" }

  org_id = var.organization_id
  role   = each.value.role
  member = "serviceAccount:${google_service_account.this.email}"
}

resource "google_billing_account_iam_member" "this" {
  for_each = { for pair in local.platform_pairs : pair.role => pair if pair.scope == "billing" }

  billing_account_id = var.billing_account_id
  role               = each.value.role
  member             = "serviceAccount:${google_service_account.this.email}"
}

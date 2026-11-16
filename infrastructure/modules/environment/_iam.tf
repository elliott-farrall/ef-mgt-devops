locals {
  folder_scopes  = { for role in var.folder_roles : role => google_folder.this.name }
  landing_scopes = { for role in var.landing_roles : role => var.landing_project_id }
  platform_pairs = { for pair in var.platform_roles : pair.role => pair }
}

resource "google_folder_iam_member" "this" {
  for_each = local.folder_scopes

  folder = each.value
  role   = each.key
  member = "serviceAccount:${google_service_account.this.email}"
}

resource "google_project_iam_member" "this" {
  for_each = local.landing_scopes

  project = each.value
  role    = each.key
  member  = "serviceAccount:${google_service_account.this.email}"
}

resource "google_project_iam_member" "platform" {
  for_each = { for pair in local.platform_pairs : pair.role => pair if startswith(pair.scope, "project:") }

  project = trimprefix(each.value.scope, "project:")
  role    = each.value.role
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

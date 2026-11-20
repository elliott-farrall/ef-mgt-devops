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

  org_id = trimprefix(var.organization_id, "organizations/")
  role   = each.value.role
  member = "serviceAccount:${google_service_account.this.email}"
}

resource "google_billing_account_iam_member" "this" {
  for_each = { for pair in local.platform_pairs : pair.role => pair if pair.scope == "billing" }

  billing_account_id = var.billing_account_id
  role               = each.value.role
  member             = "serviceAccount:${google_service_account.this.email}"
}

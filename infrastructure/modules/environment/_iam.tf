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

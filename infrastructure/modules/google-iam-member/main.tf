locals {
  kind = element(split("/", var.scope), 0)
  id   = element(split("/", var.scope), 1)
}

resource "google_folder_iam_member" "this" {
  count  = local.kind == "folders" ? 1 : 0
  folder = var.scope
  role   = var.role
  member = var.member
}

resource "google_project_iam_member" "this" {
  count   = local.kind == "projects" ? 1 : 0
  project = local.id
  role    = var.role
  member  = var.member
}

resource "google_organization_iam_member" "this" {
  count  = local.kind == "organizations" ? 1 : 0
  org_id = local.id
  role   = var.role
  member = var.member
}

resource "google_billing_account_iam_member" "this" {
  count              = local.kind == "billingAccounts" ? 1 : 0
  billing_account_id = local.id
  role               = var.role
  member             = var.member
}

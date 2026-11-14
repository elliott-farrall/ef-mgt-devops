locals {
  kind = element(split("/", var.scope), 0)
  id   = element(split("/", var.scope), 1)
}

# -- google_folder_iam_member.this: folder-level IAM binding (when scope starts with folders/) --
resource "google_folder_iam_member" "this" {
  count  = local.kind == "folders" ? 1 : 0
  folder = var.scope
  role   = var.role
  member = var.member
}

# -- google_project_iam_member.this: project-level IAM binding (when scope starts with projects/) --
resource "google_project_iam_member" "this" {
  count   = local.kind == "projects" ? 1 : 0
  project = local.id
  role    = var.role
  member  = var.member
}

# -- google_organization_iam_member.this: organisation-level IAM binding (when scope starts with organizations/) --
resource "google_organization_iam_member" "this" {
  count  = local.kind == "organizations" ? 1 : 0
  org_id = local.id
  role   = var.role
  member = var.member
}

# -- google_billing_account_iam_member.this: billing account IAM binding (when scope starts with billingAccounts/) --
resource "google_billing_account_iam_member" "this" {
  count              = local.kind == "billingAccounts" ? 1 : 0
  billing_account_id = local.id
  role               = var.role
  member             = var.member
}

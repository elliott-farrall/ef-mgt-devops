resource "google_folder_iam_member" "this" {
  count  = var.folder == null ? 0 : 1
  folder = var.folder
  role   = var.role
  member = var.member
}

resource "google_project_iam_member" "this" {
  count   = var.project == null ? 0 : 1
  project = var.project
  role    = var.role
  member  = var.member
}

resource "google_organization_iam_member" "this" {
  count  = var.organisation == null ? 0 : 1
  org_id = var.organisation
  role   = var.role
  member = var.member
}

resource "google_billing_account_iam_member" "this" {
  count              = var.billing_account == null ? 0 : 1
  billing_account_id = var.billing_account
  role               = var.role
  member             = var.member
}

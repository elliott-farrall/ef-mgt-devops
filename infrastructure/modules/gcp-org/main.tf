data "google_organization" "ef" {
  domain = var.organisation
}

data "google_billing_account" "ef" {
  display_name = var.billing.name
}

resource "google_folder" "tree" {
  for_each = var.folders

  display_name = each.key
  parent       = each.value.parent == "" ? data.google_organization.ef.name : google_folder.tree[each.value.parent].name

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_project" "platform" {
  for_each = var.projects

  name            = each.key
  project_id      = each.key
  folder_id       = google_folder.tree[each.value.parent].folder_id
  billing_account = data.google_billing_account.ef.billing_account
  labels          = var.labels

  deletion_policy = "PREVENT"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_service_account" "platform" {
  for_each = { for sa in var.iam : sa.name => sa }

  account_id   = each.value.name
  display_name = each.value.name
  project      = each.value.project
}

locals {
  bindings = flatten([
    for sa in var.iam : [
      for b in sa.bindings : [
        for r in b.roles : {
          key   = "${sa.name}|${b.scope}|${r}"
          sa    = sa.name
          scope = b.scope
          role  = r
        }
      ]
    ]
  ])

  folder_bindings  = { for x in local.bindings : x.key => x if startswith(x.scope, "folder:") }
  project_bindings = { for x in local.bindings : x.key => x if startswith(x.scope, "project:") }
  org_bindings     = { for x in local.bindings : x.key => x if x.scope == "organisation" }
  billing_bindings = { for x in local.bindings : x.key => x if x.scope == "billing" }

  member = { for sa in var.iam : sa.name => "serviceAccount:${google_service_account.platform[sa.name].email}" }
}

resource "google_folder_iam_member" "platform" {
  for_each = local.folder_bindings

  folder = google_folder.tree[trimprefix(each.value.scope, "folder:")].name
  role   = each.value.role
  member = local.member[each.value.sa]
}

resource "google_project_iam_member" "platform" {
  for_each = local.project_bindings

  project = trimprefix(each.value.scope, "project:")
  role    = each.value.role
  member  = local.member[each.value.sa]
}

resource "google_organization_iam_member" "platform" {
  for_each = local.org_bindings

  org_id = data.google_organization.ef.org_id
  role   = each.value.role
  member = local.member[each.value.sa]
}

resource "google_billing_account_iam_member" "platform" {
  for_each = local.billing_bindings

  billing_account_id = data.google_billing_account.ef.billing_account
  role               = each.value.role
  member             = local.member[each.value.sa]
}

resource "google_billing_budget" "registry" {
  for_each = { for b in var.billing.budgets : b.name => b }

  billing_account = data.google_billing_account.ef.billing_account
  display_name    = each.value.name

  amount {
    specified_amount {
      units         = tostring(each.value.amount)
      currency_code = var.billing.currency
    }
  }

  dynamic "threshold_rules" {
    for_each = each.value.thresholds
    content {
      threshold_percent = threshold_rules.value
    }
  }

  budget_filter {
    calendar_period = "MONTH"
    projects        = length(each.value.projects) > 0 ? toset(each.value.projects) : null
  }
}

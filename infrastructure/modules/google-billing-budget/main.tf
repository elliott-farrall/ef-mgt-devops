# -- locals: derive scope kind (projects, folders, organisations) or empty --
locals {
  kind = var.scope == "" ? "" : element(split("/", var.scope), 0)
}

# -- google_billing_budget.this: monthly budget alert with optional project/folder/org scoping --
resource "google_billing_budget" "this" {
  billing_account = var.billing_account_id
  display_name    = var.name

  amount {
    specified_amount {
      units         = tostring(var.amount)
      currency_code = "GBP"
    }
  }

  dynamic "threshold_rules" {
    for_each = var.thresholds
    content {
      threshold_percent = threshold_rules.value
    }
  }

  budget_filter {
    calendar_period    = "MONTH"
    projects           = local.kind == "projects" ? [element(split("/", var.scope), 1)] : null
    resource_ancestors = local.kind == "folders" || local.kind == "organizations" ? [var.scope] : null
  }
}

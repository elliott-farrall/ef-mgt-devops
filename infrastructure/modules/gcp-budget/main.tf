resource "google_billing_budget" "this" {
  billing_account = var.billing_account_id
  display_name    = var.name

  amount {
    specified_amount {
      units         = tostring(var.amount)
      currency_code = var.currency
    }
  }

  dynamic "threshold_rules" {
    for_each = var.thresholds
    content {
      threshold_percent = threshold_rules.value
    }
  }

  budget_filter {
    calendar_period = "MONTH"
    projects        = length(var.projects) > 0 ? toset(var.projects) : null
  }
}

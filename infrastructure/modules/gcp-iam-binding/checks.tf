check "single_target" {
  assert {
    condition     = length([for v in [var.folder, var.project, var.organisation, var.billing_account] : v if v != null]) == 1
    error_message = "Exactly one of folder, project, organisation, billing_account must be set."
  }
}

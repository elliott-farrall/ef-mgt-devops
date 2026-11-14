check "account_unique" {
  assert {
    condition     = length(data.cloudflare_accounts.ef.accounts) == 1
    error_message = "cf.account '${local.config.cf.account}' must match exactly one Cloudflare account."
  }
}

check "budget_projects_exist" {
  assert {
    condition = alltrue([
      for b in local.config.gcp.billing.budgets :
      alltrue([for p in try(b.projects, []) : contains(keys(local.gcp_projects), p)])
    ])
    error_message = "Every budget projects entry must name a project declared in the folder tree."
  }
}

check "project_parents_exist" {
  assert {
    condition     = alltrue([for p in local.config.gcp.projects : contains(keys(local.gcp_folders.folders), p.parent)])
    error_message = "Every project parent must name a folder in gcp.folders."
  }
}

check "iam_projects_exist" {
  assert {
    condition     = alltrue([for sa in local.config.gcp.iam : contains(keys(local.gcp_projects), sa.project)])
    error_message = "Every service account hosting project must name a project in gcp.projects."
  }
}

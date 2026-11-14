check "folder_tree_depth" {
  assert {
    condition     = local.gcp_tree_depth <= 4
    error_message = "gcp.folders nests at depth ${local.gcp_tree_depth}; locals.tf unrolls 4 levels — extend the unroll deliberately (see docs/standards.md) or flatten the tree."
  }
}

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

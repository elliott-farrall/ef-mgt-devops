check "budget_scopes_exist" {
  assert {
    condition = alltrue([
      for b in values(local.gcp_budgets) :
      b.scope == "" || !startswith(b.scope, "projects/") || contains(keys(local.gcp_projects), trimprefix(b.scope, "projects/"))
    ])
    error_message = "Every budget projects scope must name a project declared in the tree."
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

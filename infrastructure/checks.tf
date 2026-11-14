check "budget_scopes_exist" {
  assert {
    condition = alltrue([
      for b in values(local.google_billing_budgets) :
      b.scope == "" || !startswith(b.scope, "projects/") || contains(keys(local.google_projects), trimprefix(b.scope, "projects/"))
    ])
    error_message = "Every budget projects scope must name a project declared in the tree."
  }
}

check "project_parents_exist" {
  assert {
    condition     = alltrue([for p in local.config.projects.gcp : contains(keys(local.google_folders.folders), p.parent)])
    error_message = "Every project parent must name a folder in environments.folders."
  }
}

check "service_account_projects_exist" {
  assert {
    condition     = alltrue([for sa in local.config.environments.service_accounts : contains(keys(local.google_projects), sa.project)])
    error_message = "Every service account hosting project must name a project in projects.gcp."
  }
}

check "workload_identity_accounts_exist" {
  assert {
    condition     = alltrue([for id in local.config.environments.workload_identities.identities : contains(keys(local.google_service_accounts), id.service_account)])
    error_message = "Every workload identity must map to a service account in environments.service_accounts."
  }
}

check "iam_members_exist" {
  assert {
    condition     = alltrue([for x in local.config.environments.iam_members : contains(keys(local.google_service_accounts), x.member)])
    error_message = "Every IAM binding member must name a service account in environments.service_accounts."
  }
}

check "iam_member_scopes_exist" {
  assert {
    condition = alltrue([
      for x in local.config.environments.iam_members :
      contains(["organisation", "billing"], x.scope) || (startswith(x.scope, "folder:") && contains(keys(local.google_folders.folders), trimprefix(x.scope, "folder:"))) || (startswith(x.scope, "project:") && contains(keys(local.google_projects), trimprefix(x.scope, "project:")))
    ])
    error_message = "Every IAM binding scope must name a folder, project, organisation, or billing account."
  }
}

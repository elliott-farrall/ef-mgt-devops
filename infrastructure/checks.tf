# -- check budget_scopes_exist: budgets can only scope to declared projects --
check "budget_scopes_exist" {
  assert {
    condition = alltrue([
      for b in values(local.google_billing_budgets) :
      b.scope == "" || !startswith(b.scope, "projects/") || contains(keys(local.google_projects), trimprefix(b.scope, "projects/"))
    ])
    error_message = "Every budget projects scope must name a declared project."
  }
}

# -- check environment_parents_exist: parents must be named environments --
check "environment_parents_exist" {
  assert {
    condition     = alltrue([for e in [for x in local.config.environments : x if x.type != "library"] : try(e.parent, null) == null || contains([for x in [for y in local.config.environments : y if y.type != "library"] : x.name], e.parent)])
    error_message = "Every environment parent must name another environment."
  }
}



# -- check project_names_unique: project names are workspace/repo/GCP id --
check "project_names_unique" {
  assert {
    condition     = length([for p in local.environment_projects : p.name]) == length(toset([for p in local.environment_projects : p.name])) && length([for p in local.all_projects : p.repo]) == length(toset([for p in local.all_projects : p.repo]))
    error_message = "Project names double as workspace and GCP project ids and must be unique across environments; repository names double as GitHub repo ids and must be unique across projects and libraries."
  }
}

# -- check default_project_is_unique: exactly one default hosts pools and DNS --
check "default_project_is_unique" {
  assert {
    condition     = length([for p in local.environment_projects : p.name if try(p.default, false) != false]) == 1
    error_message = "Exactly one project must be marked default: true; it hosts every identity pool, service account, and DNS zone."
  }
}



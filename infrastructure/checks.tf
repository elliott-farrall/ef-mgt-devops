check "budget_scopes_exist" {
  assert {
    condition = alltrue([
      for b in values(local.google_billing_budgets) :
      b.scope == "" || !startswith(b.scope, "projects/") || contains(keys(local.google_projects), trimprefix(b.scope, "projects/"))
    ])
    error_message = "Every budget projects scope must name a declared project."
  }
}

check "environment_parents_exist" {
  assert {
    condition     = alltrue([for e in [for x in local.config.environments : x if x.type != "library"] : try(e.parent, null) == null || contains([for x in [for y in local.config.environments : y if y.type != "library"] : x.name], e.parent)])
    error_message = "Every environment parent must name another environment."
  }
}



check "project_names_unique" {
  assert {
    condition     = length([for p in local.environment_projects : p.name]) == length(toset([for p in local.environment_projects : p.name]))
    error_message = "Project names double as workspace, repository, and GCP project ids; they must be unique across all environments."
  }
}

check "project_type_matches_environment" {
  assert {
    condition     = alltrue([for p in local.environment_projects : p.type == "infrastructure" ? contains([for e in local.config.environments : e.name if e.type == "infrastructure"], p.env) : p.type == "module" ? contains([for e in local.config.environments : e.name if e.type == "library"], p.env) : !contains([for e in local.config.environments : e.name if e.type == "library"], p.env)])
    error_message = "Infrastructure projects require infrastructure environments; module projects require library environments; software projects require a folder or infrastructure environment."
  }
}

check "default_project_is_unique" {
  assert {
    condition     = length([for p in local.infrastructure_projects : p.name if try(p.default, false) != false]) == 1
    error_message = "Exactly one project must be marked default: true; it hosts every identity pool, service account, and DNS zone."
  }
}



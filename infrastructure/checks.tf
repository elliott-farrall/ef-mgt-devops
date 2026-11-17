check "deployment_environments_exist" {
  assert {
    condition = alltrue([
      for p in local.config.projects :
      alltrue([for e in try(p.environments, [p.type]) : contains([for x in local.config.environments : x.name], e)])
    ])
    error_message = "Every project deployment environment must name a declared environment; type-only projects require type to name one."
  }
}

check "environment_parents_are_groups" {
  assert {
    condition = alltrue([
      for e in local.config.environments :
      try(e.parent, null) == null || !contains([for x in local.config.environments : x.name], e.parent)
    ])
    error_message = "An environment folder parent must name a group folder, never another environment."
  }
}

check "names_and_repos_unique" {
  assert {
    condition = alltrue([
      length([for x in flatten([for p in local.config.projects : [for e in try(p.environments, [p.type]) : "ef-${e}-${p.name}"]]) : x]) == length(toset([for x in flatten([for p in local.config.projects : [for e in try(p.environments, [p.type]) : "ef-${e}-${p.name}"]]) : x])),
      length([for r in keys(local.repositories) : r]) == length(toset([for r in keys(local.repositories) : r])),
    ])
    error_message = "Deployment names double as workspace and GCP project ids and must be unique; repository names double as GitHub repo ids and must be unique across projects and modules."
  }
}

check "default_project_deploys" {
  assert {
    condition = alltrue([
      for p in local.config.projects :
      try(p.default, false) != false || length(try(p.environments, [p.type])) > 0
    ])
    error_message = "The default project must deploy: mark default: true on a project with environments, never on a library."
  }
}

check "default_project_is_unique" {
  assert {
    condition     = length([for p in local.config.projects : p.name if try(p.default, false) != false]) == 1
    error_message = "Exactly one project must be marked default: true; its landing deployment hosts every identity pool, service account, and DNS zone."
  }
}

check "budget_scopes_exist" {
  assert {
    condition = alltrue([
      for b in values(local.budgets) :
      b.scope == "" || !startswith(b.scope, "projects/") || contains(keys(local.deployments), trimprefix(b.scope, "projects/"))
    ])
    error_message = "Every budget projects scope must name a declared deployment."
  }
}

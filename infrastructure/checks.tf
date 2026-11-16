# -- check budget_scopes_exist: budgets can only scope to declared projects --
check "budget_scopes_exist" {
  assert {
    condition = alltrue([
      for b in values(local.budgets) :
      b.scope == "" || !startswith(b.scope, "projects/") || contains(keys(local.projects), trimprefix(b.scope, "projects/"))
    ])
    error_message = "Every budget projects scope must name a declared project."
  }
}

# -- check project_names_unique: project names are workspace/repo/GCP id --
check "project_names_unique" {
  assert {
    condition = alltrue([
      length([for x in flatten([for e in local.config.environments : [for p in try(e.projects, []) : merge(p, { name = "ef-${e.name}-${p.name}" })]]) : x.name]) == length(toset([for x in flatten([for e in local.config.environments : [for p in try(e.projects, []) : merge(p, { name = "ef-${e.name}-${p.name}" })]]) : x.name])),
      length([for r in concat([for x in flatten([for e in local.config.environments : [for p in try(e.projects, []) : merge(p, { repo = try(p.repo, "ef-${e.name}-${p.name}") })]]) : x.repo], [for m in try(local.config.modules, []) : try(m.repo, "ef-lib-${m.name}")]) : r]) == length(toset([for r in concat([for x in flatten([for e in local.config.environments : [for p in try(e.projects, []) : merge(p, { repo = try(p.repo, "ef-${e.name}-${p.name}") })]]) : x.repo], [for m in try(local.config.modules, []) : try(m.repo, "ef-lib-${m.name}")]) : r])),
    ])
    error_message = "Project names double as workspace and GCP project ids and must be unique across environments; repository names double as GitHub repo ids and must be unique across projects and modules."
  }
}

# -- check default_project_is_unique: exactly one default hosts pools and DNS --
check "default_project_is_unique" {
  assert {
    condition     = length([for x in flatten([for e in local.config.environments : [for p in try(e.projects, []) : p]]) : x.name if try(x.default, false) != false]) == 1
    error_message = "Exactly one project must be marked default: true; it hosts every identity pool, service account, and DNS zone."
  }
}

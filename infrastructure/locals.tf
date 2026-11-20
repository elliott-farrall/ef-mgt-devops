locals {
  config = merge([
    for f in sort(fileset("${path.root}/../environments/${var.environment}", "*.yaml")) :
    yamldecode(file("${path.root}/../environments/${var.environment}/${f}"))
  ]...)

  default_project = [for p in local.config.projects : "ef-${p.type}-${p.name}" if try(p.default, false) != false][0]

  groups = {
    for g in toset([for e in local.config.environments : e.group if try(e.group, null) != null]) : g => {
      organization_id = data.google_organization.this.id
    }
  }

  environments = {
    for e in local.config.environments : e.name => {
      name               = e.name
      organization_id    = data.google_organization.this.id
      billing_account_id = local.config.organisation.gcp.billing
      landing_project_id = local.default_project
      issuer             = "https://${local.config.organisation.tfe.hostname}"
      folder_parent      = try(e.group, null) != null ? "folders/${module.group[e.group].google_folder.folder_id}" : "organizations/${data.google_organization.this.id}"
    }
  }

  projects = {
    for p in local.config.projects : try(p.repo, "ef-${p.type}-${p.name}") => {
      name                       = p.name
      type                       = p.type
      repo                       = try(p.repo, "ef-${p.type}-${p.name}")
      environments               = try(p.environments, [p.type])
      description                = try(p.description, null)
      services                   = try(p.services, [])
      working_directory          = try(p.working_directory, "infrastructure")
      settings                   = try(p.settings, {})
      protection                 = try(p.protection, {})
      pages                      = try(p.repo, "ef-${p.type}-${p.name}") == local.default_project
      cname                      = try(p.repo, "ef-${p.type}-${p.name}") == local.default_project ? "docs.elliott-farrall.phd" : null
      billing_account_id         = local.config.organisation.gcp.billing
      zone                       = local.config.organisation.gcp.domain
      github_owner               = local.config.organisation.gh.owner
      github_app_installation    = local.config.organisation.tfe.github_app_installation
      tfc_project_ids            = { for name in try(p.environments, [p.type]) : name => module.environment[name].tfe_project.id }
      folder_ids                 = { for name in try(p.environments, [p.type]) : name => module.environment[name].google_folder.folder_id }
      wif_providers              = { for name in try(p.environments, [p.type]) : name => "//iam.googleapis.com/${module.environment[name].google_iam_workload_identity_pool_provider.name}" }
      gcp_service_account_emails = { for name in try(p.environments, [p.type]) : name => module.environment[name].google_service_account.email }
    }
  }

  modules = {
    for p in local.config.projects : try(p.repo, "ef-lib-${p.name}") => {
      name                    = p.name
      module_provider         = try(p.module_provider, "google")
      organization            = local.config.organisation.tfe.organisation
      github_app_installation = local.config.organisation.tfe.github_app_installation
      description             = try(p.description, null)
      settings                = try(p.settings, {})
      protection              = try(p.protection, {})
      zone                    = local.config.organisation.gcp.domain
      github_owner            = local.config.organisation.gh.owner
    } if p.type == "lib"
  }

  records = {
    for r in local.config.records : "${replace(r.zone, ".", "-")}-${replace(r.name, ".", "-")}-${r.type}-${substr(sha256(r.content), 0, 8)}" => {
      zone     = r.zone
      name     = r.name
      type     = r.type
      content  = r.content
      ttl      = try(r.ttl, 300)
      proxied  = try(r.proxied, false)
      priority = try(r.priority, null)
    }
  }

  budgets = {
    for b in local.config.budgets : "ef-budget-${b.name}" => {
      name               = "ef-budget-${b.name}"
      billing_account_id = local.config.organisation.gcp.billing
      amount             = b.amount
      thresholds         = b.thresholds
      scope              = try(b.scope, null) == null ? "" : b.scope
    }
  }
}

locals {
  config = merge([for f in sort(fileset("${path.root}/../environments/${var.environment}", "*.yaml")) : yamldecode(file("${path.root}/../environments/${var.environment}/${f}"))]...)

  google_default_project = [for x in flatten([for e in local.config.environments : [for p in try(e.projects, []) : merge(p, { name = "ef-${e.name}-${p.name}" })]]) : x.name if try(x.default, false) != false][0]

  environments = {
    for e in local.config.environments : e.name => {
      name               = e.name
      organization_id    = data.google_organization.ef.id
      billing_account_id = data.google_billing_account.ef.id
      landing_project_id = local.google_default_project
      issuer             = "https://${local.config.organisation.tfe.hostname}"
      roles = concat(
        [for role in ["roles/resourcemanager.projectCreator", "roles/editor", "roles/iam.serviceAccountUser", "roles/dns.admin"] : { scope = "project:${local.google_default_project}", role = role }],
        e.name == "mgt" ? [for pair in [{ scope = "organization", role = "roles/resourcemanager.organizationAdmin" }, { scope = "billing", role = "roles/billing.costsManager" }, { scope = "project:${local.google_default_project}", role = "roles/resourcemanager.projectOwner" }] : pair] : [],
      )
    }
  }

  projects = {
    for x in flatten([for e in local.config.environments : [for p in try(e.projects, []) : merge(p, { name = "ef-${e.name}-${p.name}", repo = try(p.repo, "ef-${e.name}-${p.name}"), env = e.name })]]) : x.name => {
      name                      = x.name
      environment               = x.env
      project_id                = module.environment[x.env].tfe_project.this.id
      folder_id                 = module.environment[x.env].google_folder.this.folder_id
      billing_account_id        = data.google_billing_account.ef.id
      labels                    = { environment = x.env, managed_by = "terraform", repository = x.repo }
      services                  = try(x.services, [])
      working_directory         = try(x.working_directory, "infrastructure")
      auto_apply                = try(x.auto_apply, false)
      github_owner              = local.config.organisation.gh.owner
      github_app_installation   = local.config.organisation.tfe.github_app_installation
      wif_provider              = "//iam.googleapis.com/${module.environment[x.env].google_iam_workload_identity_pool_provider.this.name}"
      gcp_service_account_email = module.environment[x.env].google_service_account.this.email
      repo                      = x.repo
      description               = try(x.description, null)
      settings                  = try(x.settings, {})
      protection                = try(x.protection, {})
    }
  }

  modules = {
    for m in try(local.config.modules, []) : try(m.repo, "ef-lib-${m.name}") => {
      name                    = m.name
      organization            = local.config.organisation.tfe.organisation
      repository_id           = "${local.config.organisation.gh.owner}/${try(m.repo, "ef-lib-${m.name}")}"
      github_app_installation = local.config.organisation.tfe.github_app_installation
      repo                    = try(m.repo, "ef-lib-${m.name}")
      description             = try(m.description, null)
      settings                = try(m.settings, {})
      protection              = try(m.protection, {})
    }
  }

  records = {
    for r in local.config.records : "${replace(r.zone, ".", "-")}-${replace(r.name, ".", "-")}-${r.type}" => {
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
      billing_account_id = data.google_billing_account.ef.id
      amount             = b.amount
      thresholds         = b.thresholds
      scope              = try(b.scope, null) == null ? "" : b.scope
    }
  }
}

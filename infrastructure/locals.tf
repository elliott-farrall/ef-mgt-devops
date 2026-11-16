locals {
  config = merge([for f in sort(fileset("${path.root}/../environments/${var.environment}", "*.yaml")) : yamldecode(file("${path.root}/../environments/${var.environment}/${f}"))]...)

  # The platform home; also consumed by data sources and checks
  google_default_project = [for x in flatten([for e in local.config.environments : [for p in try(e.projects, []) : merge(p, { name = "ef-${e.name}-${p.name}" })]]) : x.name if try(x.default, false) != false][0]

  # One entry per environment: TFC project, identity, pool, provider, bindings
  environments = {
    for e in local.config.environments : e.name => {
      name                = e.name
      organization_id     = data.google_organization.ef.id
      billing_account_id  = data.google_billing_account.ef.id
      landing_project_id  = local.google_default_project
      pool_project_number = data.google_project.landing.number
      issuer              = "https://${local.config.organisation.tfe.hostname}"
      roles = concat(
        [for role in ["roles/resourcemanager.projectCreator", "roles/editor", "roles/iam.serviceAccountUser", "roles/dns.admin"] : { scope = "project:${local.google_default_project}", role = role }],
        e.name == "mgt" ? [for pair in [{ scope = "organization", role = "roles/resourcemanager.organizationAdmin" }, { scope = "billing", role = "roles/billing.user" }, { scope = "project:${local.google_default_project}", role = "roles/resourcemanager.projectOwner" }] : pair] : [],
      )
    }
  }

  # One entry per environment project: repository, workspace, GCP project
  projects = {
    for x in flatten([for e in local.config.environments : [for p in try(e.projects, []) : merge(p, { name = "ef-${e.name}-${p.name}", repo = try(p.repo, "ef-${e.name}-${p.name}"), env = e.name })]]) : x.name => {
      name                      = x.name
      environment               = x.env
      project_id                = module.environment[x.env].tfe_project.this.id
      billing_account_id        = data.google_billing_account.ef.id
      labels                    = { environment = x.env, managed_by = "terraform", repository = x.repo }
      services                  = try(x.services, [])
      working_directory         = try(x.working_directory, "infrastructure")
      auto_apply                = try(x.auto_apply, false)
      github_owner              = local.config.organisation.gh.owner
      github_app_installation   = local.config.organisation.tfe.github_app_installation
      wif_provider              = "//iam.googleapis.com/projects/${data.google_project.landing.number}/locations/global/workloadIdentityPools/ef-${x.env}-tfc/providers/tfc-${x.env}"
      gcp_service_account_email = module.environment[x.env].google_service_account.this.email
      repo                      = x.repo
      description               = try(x.description, null)
      settings                  = try(x.settings, {})
      protection                = try(x.protection, {})
    }
  }

  # One entry per modules.yaml entry: repository + private registry module
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

  # One entry per zone: DNS zone + record sets
  zones = {
    for z in local.config.zones : replace(z.name, ".", "-") => {
      name       = replace(z.name, ".", "-")
      domain     = z.name
      project_id = local.google_default_project
      records    = try(z.records, [])
    }
  }

  # One entry per budget: billing budget alert
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

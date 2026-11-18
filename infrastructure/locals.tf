locals {
  config = merge([for f in sort(fileset("${path.root}/../environments/${var.environment}", "*.yaml")) : yamldecode(file("${path.root}/../environments/${var.environment}/${f}"))]...)

  # The landing deployment; also consumed by data sources and checks
  default_project = [for p in local.config.projects : "ef-${p.type}-${p.name}" if try(p.default, false) != false][0]

  # One entry per environment: folder, TFC project, identity, pool, provider, bindings
  environments = {
    for e in local.config.environments : e.name => {
      name               = e.name
      organization_id    = data.google_organization.ef.id
      billing_account_id = data.google_billing_account.ef.id
      landing_project_id = local.default_project
      issuer             = "https://${local.config.organisation.tfe.hostname}"
      folder_roles       = ["roles/resourcemanager.projectCreator", "roles/editor"]
      landing_roles      = ["roles/iam.serviceAccountUser", "roles/dns.admin"]
      platform_roles     = e.name == "mgt" ? [for pair in [{ scope = "organization", role = "roles/resourcemanager.organizationAdmin" }, { scope = "billing", role = "roles/billing.costsManager" }, { scope = "project:${local.default_project}", role = "roles/resourcemanager.projectOwner" }] : pair] : []
    }
  }

  # One entry per unique repository: projects and lib projects both mint repositories.
  # Status checks carry one TFC predictive check per deployment workspace building the repository.
  repositories = {
    for key, entry in {
      for p in local.config.projects : try(p.repo, "ef-${p.type}-${p.name}") => {
        repo        = try(p.repo, "ef-${p.type}-${p.name}")
        description = try(p.description, null)
        settings    = try(p.settings, {})
        protection  = try(p.protection, {})
      }
      } : key => {
      repo        = entry.repo
      description = entry.description
      settings    = entry.settings
      protection  = entry.protection
      status_checks = concat(
        ["ci / branch-name (pull_request)", "ci / terraform (pull_request)", "ci / yaml (pull_request)", "ci / shell (pull_request)"],
        [for x in values(local.projects) : "Terraform Cloud / ${x.name} (Predict)" if x.repo == entry.repo],
      )
    }
  }

  # One entry per referenced group folder: cosmetic containers for environment folders
  environment_groups = {
    for g in toset([for e in local.config.environments : e.group if try(e.group, null) != null]) : g => {
      organization_id = data.google_organization.ef.id
    }
  }

  # One entry per deployment: workspace + GCP project in the deployment environment
  projects = {
    for x in flatten([for p in local.config.projects : [for i, e in try(p.environments, [p.type]) : {
      name                      = "ef-${e}-${p.name}"
      environment               = e
      repo                      = try(p.repo, "ef-${p.type}-${p.name}")
      project_id                = module.environment[e].tfe_project.this.id
      folder_id                 = module.environment[e].google_folder.this.folder_id
      billing_account_id        = data.google_billing_account.ef.id
      labels                    = { environment = e, managed_by = "terraform", repository = try(p.repo, "ef-${p.type}-${p.name}") }
      services                  = try(p.services, [])
      working_directory         = try(p.working_directory, "infrastructure")
      queue_all_runs            = i == 0
      github_owner              = local.config.organisation.gh.owner
      github_app_installation   = local.config.organisation.tfe.github_app_installation
      wif_provider              = "//iam.googleapis.com/${module.environment[e].google_iam_workload_identity_pool_provider.this.name}"
      gcp_service_account_email = module.environment[e].google_service_account.this.email
    }]]) : x.name => x
  }

  # One entry per lib project: private registry module from its repository
  # One entry per consecutive deployment pair: chained confirmations in project environments order
  triggers = {
    for t in flatten([for p in local.config.projects : [
      for i in range(1, length(try(p.environments, [p.type]))) : {
        triggerable   = "ef-${try(p.environments, [p.type])[i]}-${p.name}"
        workspace_id  = module.project["ef-${try(p.environments, [p.type])[i]}-${p.name}"].tfe_workspace.this.id
        sourceable_id = module.project["ef-${try(p.environments, [p.type])[i - 1]}-${p.name}"].tfe_workspace.this.id
      }
      ]]) : t.triggerable => {
      workspace_id  = t.workspace_id
      sourceable_id = t.sourceable_id
    }
  }

  modules = {
    for p in local.config.projects : try(p.repo, "ef-lib-${p.name}") => {
      name                    = p.name
      module_provider         = try(p.module_provider, "google")
      organization            = local.config.organisation.tfe.organisation
      repository_id           = "${local.config.organisation.gh.owner}/${try(p.repo, "ef-lib-${p.name}")}"
      github_app_installation = local.config.organisation.tfe.github_app_installation
    } if p.type == "lib"
  }

  # One entry per record: Cloudflare DNS record in its declared zone
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

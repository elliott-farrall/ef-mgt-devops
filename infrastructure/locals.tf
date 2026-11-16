locals {
  config = merge([for f in sort(fileset("${path.root}/../environments/${var.environment}", "*.yaml")) : yamldecode(file("${path.root}/../environments/${var.environment}/${f}"))]...)

  # Infrastructure environments — flat, all top-level under the organisation root
  infrastructure_environments = local.config.environments

  # Environment projects: repository + workspace + GCP project each
  environment_projects = [for x in flatten([for e in local.config.environments : [for q in try(e.projects, []) : merge(q, { name = "ef-${e.name}-${q.name}", repo = try(q.repo, "ef-${e.name}-${q.name}"), env = e.name })]]) : x]

  # Module projects: repository + private TFC registry module each
  module_projects = [for m in try(local.config.modules, []) : merge(m, { name = "ef-lib-${m.name}", repo = try(m.repo, "ef-lib-${m.name}") })]

  # All repositories belong to one of the two lists above
  all_projects = concat(local.environment_projects, local.module_projects)

  # Default infrastructure project (the platform home)
  google_default_project = [for p in local.environment_projects : p.name if try(p.default, false) != false][0]

  # Role bindings for every environment identity; the management identity adds the platform roles
  environment_role_pairs = [for role in ["roles/resourcemanager.projectCreator", "roles/editor", "roles/iam.serviceAccountUser", "roles/dns.admin"] : { scope = "project:${local.google_default_project}", role = role }]
  platform_role_pairs    = [{ scope = "organization", role = "roles/resourcemanager.organizationAdmin" }, { scope = "billing", role = "roles/billing.user" }, { scope = "project:${local.google_default_project}", role = "roles/resourcemanager.projectOwner" }]

  # One call per environment: TFC project, identity, pool, provider, bindings
  environments = {
    for e in local.infrastructure_environments : e.name => {
      name                = e.name
      organization_id     = data.google_organization.ef.id
      billing_account_id  = local.config.organisation.gcp.billing_account_id
      landing_project_id  = local.google_default_project
      pool_project_number = data.google_project.landing.number
      issuer              = "https://${local.config.organisation.tfe.hostname}"
      roles               = concat(local.environment_role_pairs, e.name == "mgt" ? local.platform_role_pairs : [])
    }
  }

  # GitHub repository settings and branch protection, defaults merged once per repository
  github_defaults            = { visibility = "private", has_issues = true, has_projects = false, has_wiki = false, allow_merge_commit = false, allow_squash_merge = true, allow_rebase_merge = false, allow_auto_merge = false, delete_branch_on_merge = true }
  github_protection_defaults = { pattern = "main", enforce_admins = true, allows_force_pushes = false, allows_deletions = false, require_conversation_resolution = true, required_linear_history = true, required_approving_review_count = 0, dismiss_stale_reviews = true, strict_status_checks = true, status_checks = ["ci / branch-name (pull_request)", "ci / terraform (pull_request)", "ci / yaml (pull_request)", "ci / shell (pull_request)"] }
  github_settings            = { for x in local.all_projects : x.repo => merge(local.github_defaults, { name = x.repo, description = try([for y in local.all_projects : y.description if y.repo == x.repo][0], "${x.repo} repository") }, try(x.settings, {})) }
  github_protection          = { for x in local.all_projects : x.repo => merge(local.github_protection_defaults, try(x.protection, {})) }

  # One call per environment project: repository, workspace, GCP project
  projects = {
    for p in local.environment_projects : p.name => {
      name                      = p.name
      environment               = p.env
      project_id                = module.environment[p.env].tfe_project.this.id
      billing_account_id        = local.config.organisation.gcp.billing_account_id
      labels                    = { environment = p.env, managed_by = "terraform", repository = p.repo }
      services                  = try(p.services, [])
      working_directory         = try(p.working_directory, "infrastructure")
      auto_apply                = try(p.auto_apply, false)
      github_owner              = local.config.organisation.gh.owner
      github_app_installation   = local.config.organisation.tfe.github_app_installation
      wif_provider              = "//iam.googleapis.com/projects/${data.google_project.landing.number}/locations/global/workloadIdentityPools/ef-${p.env}-tfc/providers/tfc-${p.env}"
      gcp_service_account_email = module.environment[p.env].google_service_account.this.email
      repository                = local.github_settings[p.repo]
      protection                = local.github_protection[p.repo]
    }
  }

  # One call per modules.yaml entry: repository + private registry module
  modules = {
    for m in local.module_projects : m.repo => {
      name                    = trimprefix(m.repo, "ef-lib-")
      module_provider         = "google"
      organization            = local.config.organisation.tfe.organisation
      repository_id           = "${local.config.organisation.gh.owner}/${m.repo}"
      github_app_installation = local.config.organisation.tfe.github_app_installation
      repository              = local.github_settings[m.repo]
      protection              = local.github_protection[m.repo]
    }
  }

  # DNS zones hosted in the landing project
  zones = {
    for z in local.config.zones : replace(z.name, ".", "-") => {
      name       = replace(z.name, ".", "-")
      domain     = z.name
      project_id = local.google_default_project
      records    = try(z.records, [])
    }
  }

  # Billing budgets on the organisation billing account
  budgets = {
    for b in local.config.budgets : "ef-budget-${b.name}" => {
      name               = "ef-budget-${b.name}"
      billing_account_id = local.config.organisation.gcp.billing_account_id
      amount             = b.amount
      thresholds         = b.thresholds
      scope              = try(b.scope, null) == null ? "" : b.scope
    }
  }
}

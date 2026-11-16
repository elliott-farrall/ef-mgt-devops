locals {
  # Load all YAML configs from env dir and merge them into one config object
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

  google_projects = {
    for p in local.environment_projects : p.name => {
      name               = p.name
      folder_id          = null
      billing_account_id = data.google_billing_account.ef.billing_account
      labels             = { environment = p.env, managed_by = "terraform", repository = p.repo }
      services           = try(p.services, [])
    }
  }

  # Service accounts per infrastructure environment
  google_service_accounts = {
    for e in local.infrastructure_environments : "sa-${e.name}-tfc" => {
      name    = "sa-${e.name}-tfc"
      project = module.google-project[local.google_default_project].google_project.project_id
    }
  }

  # WIF pools per infrastructure environment  
  google_workload_identity_pools = {
    for e in local.infrastructure_environments : "ef-${e.name}-tfc" => {
      name    = "ef-${e.name}-tfc"
      project = module.google-project[local.google_default_project].google_project.project_id
    }
  }

  # WIF providers binding SAs to pools
  google_workload_identity_providers = {
    for e in local.infrastructure_environments : "tfc-${e.name}" => {
      name                  = "tfc-${e.name}"
      pool                  = module.google-workload-identity-pool["ef-${e.name}-tfc"].google_iam_workload_identity_pool.workload_identity_pool_id
      project               = module.google-project[local.google_default_project].google_project.project_id
      pool_project_number   = module.google-project[local.google_default_project].google_project.number
      issuer                = "https://${local.config.organisation.tfe.hostname}"
      service_account_email = module.google-service-account["sa-${e.name}-tfc"].google_service_account.email
      environment           = e.name
      attribute_condition   = "assertion.workspace_name.startsWith(\"ef-${e.name}-\")"
    }
  }

  # Role assignments for workload repos
  google_env_role_pairs = [
    { own = true, role = "roles/resourcemanager.projectCreator" },
    { own = true, role = "roles/editor" },
    { own = false, role = "roles/iam.serviceAccountUser" },
    { own = false, role = "roles/dns.admin" },
  ]

  # Platform roles for management SA
  google_platform_role_pairs = [
    { scope = "organization", role = "roles/resourcemanager.organizationAdmin" },
    { scope = "billing", role = "roles/billing.user" },
    { scope = "project:${local.google_default_project}", role = "roles/resourcemanager.projectOwner" },
  ]

  # Core IAM bindings (per-environment + platform)
  google_core_bindings = {
    for x in flatten([for e in local.infrastructure_environments : [for p in local.google_env_role_pairs : { member = "sa-${e.name}-tfc", scope = "project:${local.google_default_project}", role = p.role }]]) : "${x.member}|${x.scope}|${x.role}" => x
  }

  google_platform_bindings = {
    for x in [for p in local.google_platform_role_pairs : { member = "serviceAccount:${module.google-service-account["sa-mgt-tfc"].google_service_account.email}", scope = p.scope, role = p.role }] : "${x.member}|${x.scope}|${x.role}" => x
  }

  google_iam_members = {
    for k, v in merge(local.google_core_bindings, local.google_platform_bindings) : k => {
      scope  = v.scope
      role   = v.role
      member = v.member
    }
  }

  # Billing budgets
  google_billing_budgets = {
    for b in local.config.billing.budgets : "ef-budget-${b.name}" => {
      name               = "ef-budget-${b.name}"
      billing_account_id = data.google_billing_account.ef.billing_account
      amount             = b.amount
      thresholds         = b.thresholds
      scope              = try(b.scope, null) == null ? "" : b.scope
    }
  }

  # DNS zones (from domain.yaml or domains.yaml)
  google_dns_managed_zones = {
    for d in local.config.domain : replace(d.name, ".", "-") => {
      name       = replace(d.name, ".", "-")
      domain     = d.name
      project_id = module.google-project[local.google_default_project].google_project.project_id
      records    = try(d.records, [])
    }
  }

  # TFC projects per environment
  tfe_projects = {
    for e in local.infrastructure_environments : "ef-${e.name}" => {
      name = "ef-${e.name}"
    }
  }

  # TFC workspaces per infrastructure project
  tfe_workspaces = {
    for p in local.environment_projects : p.name => {
      name                      = p.name
      project_id                = module.tfe-project["ef-${p.env}"].tfe_project.id
      working_directory         = try(p.working_directory, "infrastructure")
      auto_apply                = try(p.auto_apply, false)
      environment               = p.env
      repo                      = p.repo
      github_owner              = local.config.organisation.gh.owner
      github_app_installation   = local.config.organisation.tfe.github_app_installation
      wif_provider              = "//iam.googleapis.com/projects/${module.google-project[local.google_default_project].google_project.number}/locations/global/workloadIdentityPools/ef-${p.env}-tfc/providers/tfc-${p.env}"
      gcp_service_account_email = module.google-service-account["sa-${p.env}-tfc"].google_service_account.email
    }
  }

  # TFC registry modules
  tfe_registry_modules = {
    for m in local.module_projects : m.repo => {
      name                    = trimprefix(m.repo, "ef-lib-")
      organization            = local.config.organisation.tfe.organisation
      repository              = "${local.config.organisation.gh.owner}/${m.repo}"
      github_app_installation = local.config.organisation.tfe.github_app_installation
    }
  }

  # GitHub repositories for every project and module
  github_repository_names = toset([for x in local.all_projects : x.repo])

  github_repositories = {
    for r in local.github_repository_names : r => {
      repository = merge(
        { visibility = "private", has_issues = true, has_projects = false, has_wiki = false, allow_merge_commit = false, allow_squash_merge = true, allow_rebase_merge = false, allow_auto_merge = false, delete_branch_on_merge = true },
        { name = r, description = try([for x in local.all_projects : x.description if x.repo == r][0], "${r} repository") },
        try([for x in local.all_projects : x.settings if x.repo == r][0], {}),
      )
      protection = merge(
        { pattern = "main", enforce_admins = true, allows_force_pushes = false, allows_deletions = false, require_conversation_resolution = true, required_linear_history = true, required_approving_review_count = 0, dismiss_stale_reviews = true, strict_status_checks = true, status_checks = ["ci / branch-name (pull_request)", "ci / terraform (pull_request)", "ci / yaml (pull_request)", "ci / shell (pull_request)"] },
        try([for x in local.all_projects : x.protection if x.repo == r][0], {}),
      )
    }
  }
}

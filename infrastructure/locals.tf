locals {
  # Load all YAML configs from env dir and merge them into one config object
  config = merge([for f in sort(fileset("${path.root}/../environments/${var.environment}", "*.yaml")) : yamldecode(file("${path.root}/../environments/${var.environment}/${f}"))]...)

  # Infrastructure environments — all top-level under org now (hub, mgt, dev, pre, prd)
  infrastructure_environments = flatten([for e in local.config.environments : [e if e.type == "infrastructure"]])

  # All projects: from environments/projects + libraries/projects
  environment_projects = flatten([
    for e in local.config.environments : 
    [for p in try(e.projects, []) : merge(p, { name = "ef-${e.name}-${p.name}", env = e.name })],
    for lib in try(local.config.projects, []) : merge(lib, { name = "ef-lib-${lib.name}", env = "lib" })
  ])

  # Filter to infrastructure-type projects only
  infrastructure_projects = [for p in local.environment_projects : p if try(p.type, "") == "infrastructure"]

  # Default infrastructure project (devops)
  google_default_project = [for p in local.infrastructure_projects : p.name if try(p.default, false) != false][0]

  # GCP resources — all projects directly under organization root (no intermediate folders)
  google_folders = {
    root_parent = data.google_organization.ef.name
    folders     = { "root" => { parent = "root" } }
  }

  google_projects = {
    for p in local.infrastructure_projects : p.name => {
      name               = p.name
      folder_id          = null
      billing_account_id = data.google_billing_account.ef.billing_account
      labels             = { environment = p.env, managed_by = "terraform", repository = try(p.repo, "ef-${p.env}-${p.name}") }
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
      scope = v.scope
      role  = v.role
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
    for p in local.infrastructure_projects : p.name => {
      name                      = p.name
      project_id                = module.tfe-project["ef-${p.env}"].tfe_project.id
      working_directory         = try(p.working_directory, "infrastructure")
      auto_apply                = try(p.auto_apply, false)
      environment               = p.env
      repo                      = try(p.repo, "ef-${p.env}-${p.name}")
      github_owner              = local.config.organisation.gh.owner
      github_app_installation   = local.config.organisation.tfe.github_app_installation
      wif_provider              = "//iam.googleapis.com/projects/${module.google-project[local.google_default_project].google_project.number}/locations/global/workloadIdentityPools/ef-${p.env}-tfc/providers/tfc-${p.env}"
      gcp_service_account_email = module.google-service-account["sa-${p.env}-tfc"].google_service_account.email
    }
  }

  # TFC registry modules for library projects
  tfe_registry_modules = {
    for p in [for x in local.environment_projects : x if x.type == "module"] : p.repo => {
      name                    = trimprefix(p.repo, "ef-lib-")
      organization            = local.config.organisation.tfe.organisation
      repository              = "${local.config.organisation.gh.owner}/${p.repo}"
      github_app_installation = local.config.organisation.tfe.github_app_installation
    }
  }

  # GitHub repositories for all projects
  github_repository_names = toset([for x in local.environment_projects : x.repo])

  github_repositories = {
    for r in local.github_repository_names : r => {
      repository = merge(
        { visibility = "private", has_issues = true, has_projects = false, has_wiki = false, allow_merge_commit = false, allow_squash_merge = true, allow_rebase_merge = false, allow_auto_merge = false, delete_branch_on_merge = true },
        { name = r, description = try([for x in local.environment_projects : x.description if x.repo == r][0], "${r} repository") },
        try([for x in local.environment_projects : x.settings if x.repo == r][0], {}),
      )
      protection = merge(
        { pattern = "main", enforce_admins = true, allows_force_pushes = false, allows_deletions = false, require_conversation_resolution = true, required_linear_history = true, required_approving_review_count = 0, dismiss_stale_reviews = true, strict_status_checks = true, status_checks = ["ci / branch-name (pull_request)", "ci / terraform (pull_request)", "ci / yaml (pull_request)", "ci / shell (pull_request)"] },
        try([for x in local.environment_projects : x.protection if x.repo == r][0], {}),
      )
    }
  }
}

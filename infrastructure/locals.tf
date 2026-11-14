locals {
  config = merge([for f in sort(fileset("${path.root}/../environments/${var.environment}", "*.yaml")) : yamldecode(file("${path.root}/../environments/${var.environment}/${f}"))]...)


  google_root_environment = [for e in local.config.environments : e.name if try(e.parent, null) == null][0]

  google_folders = {
    root_parent = data.google_organization.ef.name
    folders     = { for e in [for x in local.config.environments : x if x.type != "lib"] : "ef-${e.name}" => { parent = try(e.parent, null) == null ? "root" : "ef-${e.parent}" } }
  }

  environment_projects = flatten([for e in local.config.environments : [for p in try(e.projects, []) : merge(p, { env = e.name, repo = try(p.repo, endswith(p.name, "-${e.name}") ? trimsuffix(p.name, "-${e.name}") : p.name) })]])

  infrastructure_projects = [for p in local.environment_projects : p if p.type == "infrastructure"]

  google_default_project = [for p in local.infrastructure_projects : p.name if try(p.default, false) != false][0]

  repository_entries = local.environment_projects

  google_workload_identity_pools = {
    for e in [for x in local.config.environments : x if x.type == "terraform"] : "ef-${e.name}-tfc" => {
      name    = "ef-${e.name}-tfc"
      project = module.google-project[local.google_default_project].google_project.project_id
    }
  }

  google_projects = {
    for p in local.infrastructure_projects : p.name => {
      name               = p.name
      folder_id          = module.google-folder.google_folder["ef-${p.env}"].folder_id
      billing_account_id = data.google_billing_account.ef.billing_account
      labels             = { environment = p.env, managed_by = "terraform", repository = p.repo, tfc_project = "ef-${p.env}" }
    }
  }

  google_service_accounts = {
    for e in [for x in local.config.environments : x if x.type == "terraform"] : "sa-${e.name}-tfc" => {
      name    = "sa-${e.name}-tfc"
      project = module.google-project[local.google_default_project].google_project.project_id
    }
  }

  google_workload_identity_providers = {
    for e in [for x in local.config.environments : x if x.type == "terraform"] : "tfc-${e.name}" => {
      name                  = "tfc-${e.name}"
      pool                  = module.google-workload-identity-pool["ef-${e.name}-tfc"].google_iam_workload_identity_pool.workload_identity_pool_id
      project               = module.google-project[local.google_default_project].google_project.project_id
      pool_project_number   = module.google-project[local.google_default_project].google_project.number
      issuer                = "https://${local.config.organisation.tfe.hostname}"
      service_account_email = module.google-service-account["sa-${e.name}-tfc"].google_service_account.email
      environment           = e.name
      attribute_condition   = e.parent == local.google_root_environment ? "assertion.workspace_name.startsWith(\"ef-${e.name}-\")" : "assertion.workspace_name.endsWith(\"-${e.name}\")"
    }
  }

  google_env_role_pairs = [
    { own = true, role = "roles/resourcemanager.projectCreator" },
    { own = true, role = "roles/editor" },
    { own = false, role = "roles/iam.serviceAccountUser" },
    { own = false, role = "roles/dns.admin" },
  ]

  google_platform_role_pairs = [
    { scope = "folder:root", role = "roles/resourcemanager.folderAdmin" },
    { scope = "folder:root", role = "roles/resourcemanager.projectCreator" },
    { scope = "organisation", role = "roles/browser" },
    { scope = "billing", role = "roles/billing.user" },
  ]

  google_core_bindings = {
    for x in flatten([for e in [for x in local.config.environments : x if x.type == "terraform"] : [for p in local.google_env_role_pairs : { member = "sa-${e.name}-tfc", scope = p.own ? "folder:${e.name}" : "project:${local.google_default_project}", role = p.role }]]) : "${x.member}|${x.scope}|${x.role}" => x
  }

  google_platform_bindings = {
    for x in [for p in local.google_platform_role_pairs : { member = "sa-${var.environment}-tfc", scope = p.scope, role = p.role }] : "${x.member}|${x.scope}|${x.role}" => x
  }

  google_iam_members = {
    for k, x in merge(local.google_core_bindings, local.google_platform_bindings) : k => {
      scope = x.scope == "organisation" ? "organizations/${data.google_organization.ef.org_id}" : (
        x.scope == "billing" ? "billingAccounts/${data.google_billing_account.ef.billing_account}" : (
          startswith(x.scope, "folder:") ? module.google-folder.google_folder["ef-${trimprefix(x.scope, "folder:")}"].name : "projects/${module.google-project[trimprefix(x.scope, "project:")].google_project.project_id}"
        )
      )
      role   = x.role
      member = "serviceAccount:${module.google-service-account[x.member].google_service_account.email}"
    }
  }

  google_billing_budgets = {
    for b in local.config.billing.budgets : b.name => {
      name               = b.name
      billing_account_id = data.google_billing_account.ef.billing_account
      amount             = b.amount
      thresholds         = b.thresholds
      scope              = try(b.scope, null) == null ? "" : b.scope
    }
  }

  google_dns_managed_zones = {
    for z in local.config.domain.zones : z.name => {
      name       = z.name
      domain     = z.domain
      project_id = module.google-project[local.google_default_project].google_project.project_id
      records    = try(z.records, [])
    }
  }

  tfe_projects = {
    for e in [for x in local.config.environments : x if x.type == "terraform"] : "ef-${e.name}" => {
      name = "ef-${e.name}"
    } if e.type == "terraform"
  }

  tfe_workspaces = {
    for p in local.infrastructure_projects : p.name => {
      name                      = p.name
      project_id                = module.tfe-project["ef-${p.env}"].tfe_project.id
      working_directory         = try(p.working_directory, "infrastructure")
      auto_apply                = try(p.auto_apply, false)
      environment               = p.env
      repo                      = p.repo
      github_owner              = local.config.organisation.github.owner
      github_app_installation   = local.config.organisation.tfe.github_app_installation
      wif_provider              = "//iam.googleapis.com/projects/${module.google-project[local.google_default_project].google_project.number}/locations/global/workloadIdentityPools/ef-${p.env}-tfc/providers/tfc-${p.env}"
      gcp_service_account_email = module.google-service-account["sa-${p.env}-tfc"].google_service_account.email
    }
  }

  tfe_registry_modules = {
    for p in [for x in local.environment_projects : x if x.type == "module"] : p.repo => {
      name                    = trimprefix(p.repo, "ef-lib-")
      organization            = local.config.organisation.tfe.organisation
      repository              = "${local.config.organisation.github.owner}/${p.repo}"
      github_app_installation = local.config.organisation.tfe.github_app_installation
    }
  }

  github_repository_names = toset([for x in local.repository_entries : x.repo])

  github_repositories = {
    for r in local.github_repository_names : r => {
      repository = merge(
        { visibility = "private", has_issues = true, has_projects = false, has_wiki = false, allow_merge_commit = false, allow_squash_merge = true, allow_rebase_merge = false, allow_auto_merge = false, delete_branch_on_merge = true },
        { name = r, description = try([for x in local.repository_entries : x.description if x.repo == r][0], "${r} repository") },
        try([for x in local.repository_entries : x.settings if x.repo == r][0], {}),
      )
      protection = merge(
        { pattern = "main", enforce_admins = true, allows_force_pushes = false, allows_deletions = false, require_conversation_resolution = true, required_linear_history = true, required_approving_review_count = 0, dismiss_stale_reviews = true, strict_status_checks = true, status_checks = ["ci / branch-name (pull_request)", "ci / terraform (pull_request)", "ci / yaml (pull_request)", "ci / shell (pull_request)"] },
        try([for x in local.repository_entries : x.protection if x.repo == r][0], {}),
      )
    }
  }
}

locals {
  config = merge([for f in sort(fileset("${path.root}/../environments/${var.environment}", "*.yaml")) : yamldecode(file("${path.root}/../environments/${var.environment}/${f}"))]...)

  google_folders = {
    root_parent = data.google_organization.ef.name
    folders     = { for f in local.config.environments.folders : f.name => { parent = f.parent } }
  }

  google_projects = {
    for p in local.config.projects.gcp : p.name => {
      name               = p.name
      folder_id          = module.google-folder.google_folder[p.parent].folder_id
      billing_account_id = data.google_billing_account.ef.billing_account
      labels             = { environment = var.environment, managed_by = "terraform", repository = basename(abspath("${path.root}/..")), tfc_project = "ef-${var.environment}" }
    }
  }

  google_service_accounts = {
    for sa in local.config.environments.service_accounts : sa.name => {
      name    = sa.name
      project = module.google-project[sa.project].google_project.project_id
    }
  }

  google_wif_by_env = { for id in local.config.environments.workload_identities.identities : trimprefix(id.name, "tfc-") => id.service_account }

  google_workload_identity_providers = {
    for id in local.config.environments.workload_identities.identities : id.name => {
      name                  = id.name
      pool                  = google_iam_workload_identity_pool.tfc.workload_identity_pool_id
      project               = module.google-project[local.config.environments.workload_identities.pool_project].google_project.project_id
      pool_project_number   = module.google-project[local.config.environments.workload_identities.pool_project].google_project.number
      issuer                = local.config.environments.workload_identities.issuer
      service_account_email = module.google-service-account[id.service_account].google_service_account.email
      attribute_condition   = id.attribute_condition
      subject               = id.subject
    }
  }

  google_iam_members = {
    for x in local.config.environments.iam_members : "${x.member}|${x.scope}|${x.role}" => {
      scope = x.scope == "organisation" ? "organizations/${data.google_organization.ef.org_id}" : (
        x.scope == "billing" ? "billingAccounts/${data.google_billing_account.ef.billing_account}" : (
          startswith(x.scope, "folder:") ? module.google-folder.google_folder[trimprefix(x.scope, "folder:")].name : "projects/${module.google-project[trimprefix(x.scope, "project:")].google_project.project_id}"
        )
      )
      role   = x.role
      member = "serviceAccount:${module.google-service-account[x.member].google_service_account.email}"
    }
  }

  google_billing_budgets = {
    for b in local.config.organisation.gcp.billing.budgets : b.name => {
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
      project_id = module.google-project[z.project].google_project.project_id
      records    = try(z.records, [])
    }
  }

  tfe_projects = {
    for p in local.config.environments.tfe.projects : p.name => {
      name = p.name
    }
  }

  tfe_workspaces = {
    for w in flatten([for p in local.config.environments.tfe.projects : [for ws in try(p.workspaces, []) : { name = ws.name, project = p.name, environment = ws.environment, repo = try(ws.repo, ws.name), working_directory = try(ws.working_directory, "infrastructure"), auto_apply = try(ws.auto_apply, false) }]]) : w.name => {
      name                      = w.name
      project_id                = module.tfe-project[w.project].tfe_project.id
      working_directory         = w.working_directory
      auto_apply                = w.auto_apply
      environment               = w.environment
      repo                      = w.repo
      github_owner              = local.config.organisation.github.owner
      github_app_installation   = local.config.organisation.tfe.github_app_installation
      wif_provider              = "//iam.googleapis.com/projects/${module.google-project[local.config.environments.workload_identities.pool_project].google_project.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.tfc.workload_identity_pool_id}/providers/tfc-${w.environment}"
      gcp_service_account_email = module.google-service-account[local.google_wif_by_env[w.environment]].google_service_account.email
    }
  }

  github_repositories = {
    for r in local.config.projects.github : r.name => {
      repository = merge(
        { visibility = "private", has_issues = true, has_projects = false, has_wiki = false, allow_merge_commit = false, allow_squash_merge = true, allow_rebase_merge = false, allow_auto_merge = false, delete_branch_on_merge = true },
        try(r.settings, {}),
        { name = r.name, description = r.description },
      )
      protection = merge(
        { pattern = "main", enforce_admins = true, allows_force_pushes = false, allows_deletions = false, require_conversation_resolution = true, required_linear_history = true, required_approving_review_count = 0, dismiss_stale_reviews = true, strict_status_checks = true, status_checks = ["ci / branch-name (pull_request)", "ci / terraform (pull_request)", "ci / yaml (pull_request)", "ci / shell (pull_request)"] },
        try(r.protection, {}),
      )
    }
  }
}

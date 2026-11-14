locals {
  config = merge([for f in sort(fileset("${path.root}/../environments/${var.environment}", "*.yaml")) : yamldecode(file("${path.root}/../environments/${var.environment}/${f}"))]...)

  gcp_folders = {
    root_parent = data.google_organization.ef.name
    folders     = { for f in local.config.gcp.folders : f.name => { parent = f.parent } }
  }

  gcp_projects = {
    for p in local.config.gcp.projects : p.name => {
      name               = p.name
      folder_id          = module.gcp-folders.folder_ids[p.parent]
      billing_account_id = data.google_billing_account.ef.billing_account
      labels             = { environment = var.environment, managed_by = "terraform", repository = basename(abspath("${path.root}/..")), tfc_project = "ef-${var.environment}" }
    }
  }

  gcp_identities = {
    for sa in local.config.gcp.iam : sa.name => {
      name    = sa.name
      project = module.gcp-project[sa.project].project_id
    }
  }

  gcp_bindings = {
    for x in flatten([for sa in local.config.gcp.iam : [for b in sa.bindings : [for r in b.roles : { key = "${sa.name}|${b.scope}|${r}", sa = sa.name, scope = b.scope, role = r }]]]) : x.key => {
      scope = x.scope == "organisation" ? "organizations/${data.google_organization.ef.org_id}" : (
        x.scope == "billing" ? "billingAccounts/${data.google_billing_account.ef.billing_account}" : (
          startswith(x.scope, "folder:") ? module.gcp-folders.folder_names[trimprefix(x.scope, "folder:")] : "projects/${module.gcp-project[trimprefix(x.scope, "project:")].project_id}"
        )
      )
      role   = x.role
      member = "serviceAccount:${module.gcp-service-account[x.sa].email}"
    }
  }

  gcp_budgets = {
    for b in local.config.gcp.billing.budgets : b.name => {
      name               = b.name
      billing_account_id = data.google_billing_account.ef.billing_account
      currency           = local.config.gcp.billing.currency
      amount             = b.amount
      thresholds         = b.thresholds
      projects           = try(b.projects, [])
    }
  }

  tfc_projects = {
    for p in local.config.tfc.projects : p.name => {
      name         = p.name
      organisation = data.tfe_organization.ef.name
    }
  }

  tfc_workspaces = {
    for w in flatten([for p in local.config.tfc.projects : [for ws in try(p.workspaces, []) : { name = ws.name, project = p.name, working_directory = try(ws.working_directory, "infrastructure"), auto_apply = try(ws.auto_apply, false) }]]) : w.name => {
      name              = w.name
      organisation      = data.tfe_organization.ef.name
      project_id        = module.tfc-project[w.project].id
      working_directory = w.working_directory
      auto_apply        = w.auto_apply
    }
  }

  cf_zones = {
    for z in local.config.cf.zones : z.name => {
      account_id = data.cloudflare_accounts.ef.accounts[0].id
      zone       = z.name
      plan       = try(z.plan, "free")
    }
  }

  gh_repositories = {
    for r in local.config.gh.repositories : r.name => {
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

module "gcp_org" {
  source       = "./modules/gcp-org"
  folders      = local.gcp_folder_nodes
  projects     = local.gcp_project_nodes
  organisation = local.gcp.organisation
  billing      = local.gcp.billing
  iam          = local.gcp.iam
  labels       = local.labels
}

module "tfc" {
  source       = "./modules/tfc"
  organisation = local.tfc.organisation
  projects     = local.tfc_project_names
  workspaces   = local.tfc_workspace_nodes
}

module "cf" {
  source  = "./modules/cf"
  account = local.cf.account
  zones   = local.cf_zones
}

module "gh" {
  source       = "./modules/gh"
  repositories = local.gh_repositories
  protections  = local.gh_protections
}

check "config_placeholders" {
  assert {
    condition = alltrue([
      for v in [local.gcp.organisation, local.gcp.billing, local.cf.account] :
      !strcontains(lower(tostring(v)), "replace_me")
    ])
    error_message = "environments/${var.environment}/ still contains REPLACE_ME placeholders — fill in real IDs before planning."
  }
}

check "folder_tree_depth" {
  assert {
    condition     = !local.gcp_tree_too_deep
    error_message = "gcp.folders nests deeper than the 4 folder levels locals.tf unrolls — extend the unroll deliberately (see docs/standards.md) or flatten the tree."
  }
}

check "iam_projects_exist" {
  assert {
    condition     = alltrue([for sa in local.gcp.iam : contains(keys(local.gcp_project_nodes), sa.project)])
    error_message = "Every gcp.iam entry must name a hosting project declared in the folder tree."
  }
}

check "budget_projects_exist" {
  assert {
    condition = alltrue([
      for b in local.gcp.billing.budgets :
      alltrue([for p in try(b.projects, []) : contains(keys(local.gcp_project_nodes), p)])
    ])
    error_message = "Every budget projects entry must name a project declared in the folder tree."
  }
}

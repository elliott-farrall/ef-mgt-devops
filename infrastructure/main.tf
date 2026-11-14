module "gcp_org" {
  source          = "./modules/gcp-org"
  folders         = local.gcp_folder_nodes
  projects        = local.gcp_project_nodes
  organisation_id = local.gcp.organisation_id
  billing_account = local.gcp.billing_account
  labels          = local.labels
}

module "tfc" {
  source       = "./modules/tfc"
  organisation = local.tfc.organisation
  projects     = local.tfc_project_names
  workspaces   = local.tfc_workspace_nodes
}

module "cf" {
  source = "./modules/cf"
  config = local.cf
  labels = local.labels
}

module "gh" {
  source       = "./modules/gh"
  repositories = local.gh_repositories
  protections  = local.gh_protections
}

check "config_placeholders" {
  assert {
    condition = alltrue([
      for v in [local.gcp.organisation_id, local.gcp.billing_account, local.cf.account_id] :
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

module "gcp-folder-root" {
  source   = "./modules/gcp-folder"
  for_each = { for k, v in local.gcp_folders : k => v if v.depth == 1 }

  name   = each.key
  parent = data.google_organization.ef.name
}

module "gcp-folder-plane" {
  source   = "./modules/gcp-folder"
  for_each = { for k, v in local.gcp_folders : k => v if v.depth == 2 }

  name   = each.key
  parent = module.gcp-folder-root[each.value.parent].folder_name
}

module "gcp-folder-ladder" {
  source   = "./modules/gcp-folder"
  for_each = { for k, v in local.gcp_folders : k => v if v.depth == 3 }

  name   = each.key
  parent = module.gcp-folder-plane[each.value.parent].folder_name
}

module "gcp-folder-leaf" {
  source   = "./modules/gcp-folder"
  for_each = { for k, v in local.gcp_folders : k => v if v.depth == 4 }

  name   = each.key
  parent = module.gcp-folder-ladder[each.value.parent].folder_name
}

module "gcp-project" {
  source   = "./modules/gcp-project"
  for_each = local.gcp_project_nodes

  name               = each.key
  folder_id          = local.all_folder_ids[each.value.parent]
  billing_account_id = data.google_billing_account.ef.billing_account
  labels             = local.labels
}

module "gcp-service-account" {
  source   = "./modules/gcp-service-account"
  for_each = { for sa in local.gcp.iam : sa.name => sa }

  name    = each.key
  project = module.gcp-project[each.value.project].project_id
}

module "gcp-iam-binding" {
  source   = "./modules/gcp-iam-binding"
  for_each = { for x in local.gcp_iam_bindings : x.key => x }

  role            = each.value.role
  member          = "serviceAccount:${module.gcp-service-account[each.value.sa].email}"
  folder          = startswith(each.value.scope, "folder:") ? local.all_folder_names[trimprefix(each.value.scope, "folder:")] : null
  project         = startswith(each.value.scope, "project:") ? module.gcp-project[trimprefix(each.value.scope, "project:")].project_id : null
  organisation    = each.value.scope == "organisation" ? data.google_organization.ef.org_id : null
  billing_account = each.value.scope == "billing" ? data.google_billing_account.ef.billing_account : null
}

module "gcp-budget" {
  source   = "./modules/gcp-budget"
  for_each = { for b in local.gcp.billing.budgets : b.name => b }

  name               = each.value.name
  billing_account_id = data.google_billing_account.ef.billing_account
  currency           = local.gcp.billing.currency
  amount             = each.value.amount
  thresholds         = each.value.thresholds
  projects           = each.value.projects
}

module "tfc-project" {
  source   = "./modules/tfc-project"
  for_each = toset(local.tfc_project_names)

  name         = each.value
  organization = data.tfe_organization.ef.name
}

module "tfc-workspace" {
  source   = "./modules/tfc-workspace"
  for_each = local.tfc_workspace_nodes

  name              = each.value.name
  organization      = data.tfe_organization.ef.name
  project_id        = module.tfc-project[each.value.project].id
  working_directory = each.value.working_directory
  auto_apply        = each.value.auto_apply
}

module "cf-zone" {
  source   = "./modules/cf-zone"
  for_each = local.cf_zones

  account_id = data.cloudflare_accounts.ef.accounts[0].id
  zone       = each.value.name
  plan       = each.value.plan
}

module "gh-repository" {
  source   = "./modules/gh-repository"
  for_each = local.gh_repositories

  repository = each.value
  protection = local.gh_protections[each.key]
}

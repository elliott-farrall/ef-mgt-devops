module "gcp-folders" {
  source = "./modules/gcp-folders"

  tree = local.gcp_folders
}

module "gcp-project" {
  source   = "./modules/gcp-project"
  for_each = local.gcp_projects

  name               = each.value.name
  folder_id          = each.value.folder_id
  billing_account_id = each.value.billing_account_id
  labels             = each.value.labels
}

module "gcp-service-account" {
  source   = "./modules/gcp-service-account"
  for_each = local.gcp_identities

  name    = each.value.name
  project = each.value.project
}

module "gcp-iam-binding" {
  source   = "./modules/gcp-iam-binding"
  for_each = local.gcp_bindings

  role            = each.value.role
  member          = each.value.member
  folder          = each.value.folder
  project         = each.value.project
  organisation    = each.value.organisation
  billing_account = each.value.billing_account
}

module "gcp-budget" {
  source   = "./modules/gcp-budget"
  for_each = local.gcp_budgets

  name               = each.value.name
  billing_account_id = each.value.billing_account_id
  currency           = each.value.currency
  amount             = each.value.amount
  thresholds         = each.value.thresholds
  projects           = each.value.projects
}

module "tfc-project" {
  source   = "./modules/tfc-project"
  for_each = local.tfc_projects

  name         = each.value.name
  organisation = each.value.organisation
}

module "tfc-workspace" {
  source   = "./modules/tfc-workspace"
  for_each = local.tfc_workspaces

  name              = each.value.name
  organisation      = each.value.organisation
  project_id        = each.value.project_id
  working_directory = each.value.working_directory
  auto_apply        = each.value.auto_apply
}

module "cf-zone" {
  source   = "./modules/cf-zone"
  for_each = local.cf_zones

  account_id = each.value.account_id
  zone       = each.value.zone
  plan       = each.value.plan
}

module "gh-repository" {
  source   = "./modules/gh-repository"
  for_each = local.gh_repositories

  repository = each.value.repository
  protection = each.value.protection
}

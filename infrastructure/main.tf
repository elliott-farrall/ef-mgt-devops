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

  depends_on = [module.gcp-folders]
}

module "gcp-service-account" {
  source   = "./modules/gcp-service-account"
  for_each = local.gcp_service_accounts

  name    = each.value.name
  project = each.value.project

  depends_on = [module.gcp-project]
}

module "gcp-iam-binding" {
  source   = "./modules/gcp-iam-binding"
  for_each = local.gcp_iam_bindings

  scope  = each.value.scope
  role   = each.value.role
  member = each.value.member

  depends_on = [module.gcp-folders, module.gcp-project, module.gcp-service-account]
}

module "gcp-budget" {
  source   = "./modules/gcp-budget"
  for_each = local.gcp_budgets

  name               = each.value.name
  billing_account_id = each.value.billing_account_id
  amount             = each.value.amount
  thresholds         = each.value.thresholds
  scope              = each.value.scope

  depends_on = [module.gcp-project]
}

module "gcp-dns" {
  source   = "./modules/gcp-dns"
  for_each = local.gcp_dns

  name       = each.value.name
  domain     = each.value.domain
  project_id = each.value.project_id
  records    = each.value.records

  depends_on = [module.gcp-project]
}

module "tfc-project" {
  source   = "./modules/tfc-project"
  for_each = local.tfc_projects

  name = each.value.name
}

module "tfc-workspace" {
  source   = "./modules/tfc-workspace"
  for_each = local.tfc_workspaces

  name                       = each.value.name
  project_id                 = each.value.project_id
  working_directory          = each.value.working_directory
  auto_apply                 = each.value.auto_apply
  github_owner               = each.value.github_owner
  github_app_installation_id = each.value.github_app_installation_id

  depends_on = [module.tfc-project, module.gh-repository]
}

module "gh-repository" {
  source   = "./modules/gh-repository"
  for_each = local.gh_repositories

  repository = each.value.repository
  protection = each.value.protection
}

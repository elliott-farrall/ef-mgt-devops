resource "google_iam_workload_identity_pool" "tfc" {
  workload_identity_pool_id = local.config.environments.workload_identities.pool
  project                   = module.google-project[local.config.environments.workload_identities.pool_project].google_project.project_id
}

module "google-folder" {
  source = "./modules/google-folder"

  tree = local.google_folders
}

module "google-project" {
  source   = "./modules/google-project"
  for_each = local.google_projects

  name               = each.value.name
  folder_id          = each.value.folder_id
  billing_account_id = each.value.billing_account_id
  labels             = each.value.labels

  depends_on = [module.google-folder]
}

module "google-service-account" {
  source   = "./modules/google-service-account"
  for_each = local.google_service_accounts

  name    = each.value.name
  project = each.value.project

  depends_on = [module.google-project]
}

module "google-workload-identity-provider" {
  source   = "./modules/google-workload-identity-provider"
  for_each = local.google_workload_identity_providers

  name                  = each.value.name
  pool                  = each.value.pool
  project               = each.value.project
  pool_project_number   = each.value.pool_project_number
  issuer                = each.value.issuer
  service_account_email = each.value.service_account_email
  attribute_condition   = each.value.attribute_condition
  subject               = each.value.subject

  depends_on = [module.google-service-account]
}

module "google-iam-member" {
  source   = "./modules/google-iam-member"
  for_each = local.google_iam_members

  scope  = each.value.scope
  role   = each.value.role
  member = each.value.member

  depends_on = [module.google-folder, module.google-project, module.google-service-account]
}

module "google-billing-budget" {
  source   = "./modules/google-billing-budget"
  for_each = local.google_billing_budgets

  name               = each.value.name
  billing_account_id = each.value.billing_account_id
  amount             = each.value.amount
  thresholds         = each.value.thresholds
  scope              = each.value.scope

  depends_on = [module.google-project]
}

module "google-dns-managed-zone" {
  source   = "./modules/google-dns-managed-zone"
  for_each = local.google_dns_managed_zones

  name       = each.value.name
  domain     = each.value.domain
  project_id = each.value.project_id
  records    = each.value.records

  depends_on = [module.google-project]
}

module "tfe-project" {
  source   = "./modules/tfe-project"
  for_each = local.tfe_projects

  name = each.value.name
}

module "tfe-workspace" {
  source   = "./modules/tfe-workspace"
  for_each = local.tfe_workspaces

  name                      = each.value.name
  project_id                = each.value.project_id
  working_directory         = each.value.working_directory
  auto_apply                = each.value.auto_apply
  environment               = each.value.environment
  repo                      = each.value.repo
  github_owner              = each.value.github_owner
  github_app_installation   = each.value.github_app_installation
  wif_provider              = each.value.wif_provider
  gcp_service_account_email = each.value.gcp_service_account_email

  depends_on = [module.tfe-project, module.github-repository]
}

module "github-repository" {
  source   = "./modules/github-repository"
  for_each = local.github_repositories

  repository = each.value.repository
  protection = each.value.protection
}

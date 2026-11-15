# Google Project Module — creates projects + enables APIs via google_project_service
module "google-project" {
  source   = "./modules/google-project"
  for_each = local.google_projects

  name               = each.value.name
  folder_id          = each.value.folder_id
  billing_account_id = each.value.billing_account_id
  labels             = each.value.labels
  services           = each.value.services
}

# Workload Identity Pools — one per environment
module "google-workload-identity-pool" {
  source   = "./modules/google-workload-identity-pool"
  for_each = local.google_workload_identity_pools

  name    = each.value.name
  project = each.value.project
}

# Service Accounts — one per infrastructure environment  
module "google-service-account" {
  source   = "./modules/google-service-account"
  for_each = local.google_service_accounts

  name    = each.value.name
  project = each.value.project
}

# WIF Providers — bind SAs to pools, create providers for federation
module "google-workload-identity-provider" {
  source   = "./modules/google-workload-identity-provider"
  for_each = local.google_workload_identity_providers

  name                  = each.value.name
  pool                  = each.value.pool
  project               = each.value.project
  pool_project_number   = each.value.pool_project_number
  issuer                = each.value.issuer
  service_account_email = each.value.service_account_email
  environment           = each.value.environment
  attribute_condition   = each.value.attribute_condition
}

# IAM Members — grant roles to workload repos
module "google-iam-member" {
  source   = "./modules/google-iam-member"
  for_each = local.google_iam_members

  scope  = each.value.scope
  role   = each.value.role
  member = each.value.member
}

# Billing Budgets — control spend per environment
module "google-billing-budget" {
  source   = "./modules/google-billing-budget"
  for_each = local.google_billing_budgets

  name               = each.value.name
  billing_account_id = each.value.billing_account_id
  amount             = each.value.amount
  thresholds         = each.value.thresholds
  scope              = each.value.scope
}

# DNS Managed Zones — zone management for domains
module "google-dns-managed-zone" {
  source   = "./modules/google-dns-managed-zone"
  for_each = local.google_dns_managed_zones

  name       = each.value.name
  domain     = each.value.domain
  project_id = each.value.project_id
  records    = each.value.records
}

# TFC Projects
module "tfe-project" {
  source   = "./modules/tfe-project"
  for_each = local.tfe_projects

  name = each.value.name
}

# TFC Workspaces — workspace per infra project with WIF
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
}

# TFC Registry Modules — private registry for library modules
module "tfe-registry-module" {
  source   = "./modules/tfe-registry-module"
  for_each = local.tfe_registry_modules

  name                    = each.value.name
  organization            = each.value.organization
  repository              = each.value.repository
  github_app_installation = each.value.github_app_installation
}

# GitHub Repositories — create all project repos
module "github-repository" {
  source   = "./modules/github-repository"
  for_each = local.github_repositories

  repository = each.value.repository
  protection = each.value.protection
}

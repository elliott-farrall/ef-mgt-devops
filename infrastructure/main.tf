module "environment" {
  source   = "./modules/environment"
  for_each = local.environments

  name               = each.value.name
  organization_id    = each.value.organization_id
  billing_account_id = each.value.billing_account_id
  landing_project_id = each.value.landing_project_id
  issuer             = each.value.issuer
  folder_roles       = each.value.folder_roles
  landing_roles      = each.value.landing_roles
  platform_roles     = each.value.platform_roles
}

module "repository" {
  source   = "./modules/repository"
  for_each = local.repositories

  repo          = each.value.repo
  description   = each.value.description
  settings      = each.value.settings
  protection    = each.value.protection
  status_checks = each.value.status_checks
}

module "project" {
  source   = "./modules/project"
  for_each = local.deployments

  name                      = each.value.name
  environment               = each.value.environment
  repo                      = each.value.repo
  project_id                = each.value.project_id
  folder_id                 = each.value.folder_id
  billing_account_id        = each.value.billing_account_id
  labels                    = each.value.labels
  services                  = each.value.services
  working_directory         = each.value.working_directory
  github_owner              = each.value.github_owner
  github_app_installation   = each.value.github_app_installation
  wif_provider              = each.value.wif_provider
  gcp_service_account_email = each.value.gcp_service_account_email

  depends_on = [module.environment, module.repository]
}

module "module" {
  source   = "./modules/module"
  for_each = local.modules

  name                    = each.value.name
  module_provider         = each.value.module_provider
  organization            = each.value.organization
  repository_id           = each.value.repository_id
  github_app_installation = each.value.github_app_installation

  depends_on = [module.repository]
}

module "record" {
  source   = "./modules/record"
  for_each = local.records

  zone     = each.value.zone
  name     = each.value.name
  type     = each.value.type
  content  = each.value.content
  ttl      = each.value.ttl
  proxied  = each.value.proxied
  priority = each.value.priority

  depends_on = [module.project]
}

module "budget" {
  source   = "./modules/budget"
  for_each = local.budgets

  name               = each.value.name
  billing_account_id = each.value.billing_account_id
  amount             = each.value.amount
  thresholds         = each.value.thresholds
  scope              = each.value.scope

  depends_on = [module.project]
}

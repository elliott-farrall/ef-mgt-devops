module "group" {
  source   = "./modules/group"
  for_each = local.environment_groups

  name            = each.value.name
  organization_id = each.value.organization_id
}

module "environment" {
  source   = "./modules/environment"
  for_each = local.environments

  name               = each.value.name
  organization_id    = each.value.organization_id
  folder_parent      = each.value.folder_parent
  billing_account_id = each.value.billing_account_id
  landing_project_id = each.value.landing_project_id
  issuer             = each.value.issuer
  folder_roles       = each.value.folder_roles
  landing_roles      = each.value.landing_roles
  platform_roles     = each.value.platform_roles

  depends_on = [module.group]
}

module "repository" {
  source   = "./modules/repository"
  for_each = local.repositories

  repo          = each.value.repo
  description   = each.value.description
  settings      = each.value.settings
  protection    = each.value.protection
  status_checks = each.value.status_checks
  pages         = each.value.pages
  cname         = each.value.cname
  zone          = each.value.zone
  github_owner  = each.value.github_owner
}

module "project" {
  source   = "./modules/project"
  for_each = local.projects

  name                      = each.value.name
  environment               = each.value.environment
  repo                      = each.value.repo
  project_id                = each.value.project_id
  folder_id                 = each.value.folder_id
  billing_account_id        = each.value.billing_account_id
  labels                    = each.value.labels
  services                  = each.value.services
  working_directory         = each.value.working_directory
  queue_all_runs            = each.value.queue_all_runs
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

module "trigger" {
  source   = "./modules/trigger"
  for_each = local.triggers

  workspace_id  = each.value.workspace_id
  sourceable_id = each.value.sourceable_id

  depends_on = [module.project]
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

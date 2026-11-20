module "group" {
  source   = "./modules/group"
  for_each = local.groups

  name            = each.key
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

  depends_on = [module.group]
}

module "project" {
  source   = "./modules/project"
  for_each = local.projects

  name                       = each.value.name
  environments               = each.value.environments
  repo                       = each.value.repo
  description                = each.value.description
  settings                   = each.value.settings
  protection                 = each.value.protection
  pages                      = each.value.pages
  cname                      = each.value.cname
  zone                       = each.value.zone
  github_owner               = each.value.github_owner
  github_app_installation    = each.value.github_app_installation
  billing_account_id         = each.value.billing_account_id
  services                   = each.value.services
  working_directory          = each.value.working_directory
  tfc_project_ids            = each.value.tfc_project_ids
  folder_ids                 = each.value.folder_ids
  wif_providers              = each.value.wif_providers
  gcp_service_account_emails = each.value.gcp_service_account_emails

  depends_on = [module.environment]
}

module "module" {
  source   = "./modules/module"
  for_each = local.modules

  name                    = each.value.name
  module_provider         = each.value.module_provider
  organization            = each.value.organization
  description             = each.value.description
  settings                = each.value.settings
  protection              = each.value.protection
  zone                    = each.value.zone
  github_owner            = each.value.github_owner
  github_app_installation = each.value.github_app_installation
}

module "record" {
  source   = "./modules/record"
  for_each = local.records

  zone_id  = data.cloudflare_zone.zones[each.value.zone].id
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

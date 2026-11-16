# Environments — TFC project, identity, pool, provider, bindings per environment
module "environment" {
  source   = "./modules/environment"
  for_each = local.environments

  name                = each.value.name
  organization_id     = each.value.organization_id
  billing_account_id  = each.value.billing_account_id
  landing_project_id  = each.value.landing_project_id
  pool_project_number = each.value.pool_project_number
  issuer              = each.value.issuer
  roles               = each.value.roles
}

# Projects — repository, workspace, GCP project per environment project
module "project" {
  source   = "./modules/project"
  for_each = local.projects

  name                      = each.value.name
  environment               = each.value.environment
  project_id                = each.value.project_id
  billing_account_id        = each.value.billing_account_id
  labels                    = each.value.labels
  services                  = each.value.services
  working_directory         = each.value.working_directory
  auto_apply                = each.value.auto_apply
  github_owner              = each.value.github_owner
  github_app_installation   = each.value.github_app_installation
  wif_provider              = each.value.wif_provider
  gcp_service_account_email = each.value.gcp_service_account_email
  repository                = each.value.repository
  protection                = each.value.protection
}

# Modules — repository + private registry module per modules.yaml entry
module "module" {
  source   = "./modules/module"
  for_each = local.modules

  name                    = each.value.name
  module_provider         = each.value.module_provider
  organization            = each.value.organization
  repository_id           = each.value.repository_id
  github_app_installation = each.value.github_app_installation
  repository              = each.value.repository
  protection              = each.value.protection
}

# Zones — DNS zone + record sets per zone
module "zone" {
  source   = "./modules/zone"
  for_each = local.zones

  name       = each.value.name
  domain     = each.value.domain
  project_id = each.value.project_id
  records    = each.value.records

  depends_on = [module.project]
}

# Budgets — budget alert per budget
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

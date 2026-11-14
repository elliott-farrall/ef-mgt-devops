# All complexity lives here: YAML load + merge, naming, labels. Modules and
# resources consume these derived locals only.

locals {
  # environments/<name>/*.yaml, merged alphabetically into one flat config map.
  env_dir    = "${path.root}/../environments/${var.environment}"
  config     = merge([for f in sort(fileset(local.env_dir, "*.yaml")) : yamldecode(file("${local.env_dir}/${f}"))]...)
  repository = basename(abspath("${path.root}/.."))

  # GCP
  organization_id = local.config.organization_id
  billing_account = local.config.billing_account
  gcp_region      = local.config.gcp_region
  landing_project = local.config.landing_project
  folders         = { for f in local.config.folders : f.name => f }

  # Terraform Cloud
  tfc_hostname     = local.config.tfc_hostname
  tfc_organization = local.config.tfc_organization
  tfc_projects     = local.config.tfc_projects
  tfc_workspace    = local.config.tfc_workspace

  # Cloudflare
  cf_account_id = local.config.cf_account_id
  cf_apex_zone  = local.config.cf_apex_zone

  # Naming: everything lower kebab-case, prefixed ef-, environment-scoped.
  prefix            = "ef"
  tfc_plane_project = "ef-${var.environment}"

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    repository  = local.repository
    tfc_project = local.tfc_plane_project
  }
}

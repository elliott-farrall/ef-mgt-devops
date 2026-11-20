locals {
  folder_roles  = ["roles/resourcemanager.projectCreator", "roles/editor"]
  landing_roles = ["roles/iam.serviceAccountUser", "roles/dns.admin"]
  platform_pairs = var.name == "mgt" ? { for pair in [
    { scope = "organization", role = "roles/resourcemanager.organizationAdmin" },
    { scope = "billing", role = "roles/billing.costsManager" },
    { scope = "project:${var.landing_project_id}", role = "roles/resourcemanager.projectOwner" },
  ] : pair.role => pair } : {}

  folder_scopes  = { for role in local.folder_roles : role => google_folder.this.name }
  landing_scopes = { for role in local.landing_roles : role => var.landing_project_id }
  project_pairs = merge(
    { for role in local.landing_roles : role => var.landing_project_id },
    { for pair in local.platform_pairs : pair.role => trimprefix(pair.scope, "project:") if startswith(pair.scope, "project:") },
  )
}

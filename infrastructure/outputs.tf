output "folder_ids" {
  description = "GCP folder IDs keyed by name across the whole resource tree."
  value       = module.gcp_org.folder_ids
}

output "project_ids" {
  description = "Platform project IDs keyed by project ID across the whole resource tree."
  value       = module.gcp_org.project_ids
}

output "tfc_workspace_ids" {
  description = "Terraform Cloud workspace IDs keyed by workspace name."
  value       = module.tfc.workspace_ids
}

output "cf_zone_ids" {
  description = "Cloudflare zone IDs keyed by zone name."
  value       = module.cf.zone_ids
}

output "gh_repository_ids" {
  description = "GitHub repository slugs keyed by name."
  value       = module.gh.repository_ids
}

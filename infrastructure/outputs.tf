output "folder_ids" {
  description = "GCP folder IDs by name (ef-root, ef-mgt, ef-hub, ef-app, ef-dev, ef-pre, ef-prd)."
  value       = module.gcp_org.folder_ids
}

output "landing_project_id" {
  description = "The ef-mgt-devops landing project ID."
  value       = module.gcp_org.landing_project_id
}

output "tfc_workspace_id" {
  description = "Terraform Cloud workspace ID for this repository."
  value       = module.tfc.workspace_id
}

output "cf_apex_zone_id" {
  description = "Cloudflare apex zone ID."
  value       = module.cloudflare.apex_zone_id
}

output "tfe_workspace" {
  description = "The TFE workspace created for this infrastructure project."
  value       = tfe_workspace.this
}

output "tfe_workspace_settings" {
  description = "Workspace settings resource (execution mode set to remote)."
  value       = tfe_workspace_settings.this
}

output "tfe_variable_environment" {
  description = "The environment slot variable injected into the workspace as a terraform variable."
  value       = tfe_variable.environment
}

output "tfe_variable_wif_provider" {
  description = "The WIF provider variable exposed to runs as an environment variable."
  value       = tfe_variable.wif_provider
}

output "tfe_variable_gcp_impersonate_service_account" {
  description = "The GCP service account variable used for impersonation after workload identity token exchange."
  value       = tfe_variable.gcp_impersonate_service_account
}

output "tfe_workspace" {
  value = tfe_workspace.this
}

output "tfe_workspace_settings" {
  value = tfe_workspace_settings.this
}

output "tfe_variable_environment" {
  value = tfe_variable.environment
}

output "tfe_variable_wif_provider" {
  value = tfe_variable.wif_provider
}

output "tfe_variable_gcp_impersonate_service_account" {
  value = tfe_variable.gcp_impersonate_service_account
}

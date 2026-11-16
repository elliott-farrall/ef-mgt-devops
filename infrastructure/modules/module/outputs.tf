output "github_repository" {
  description = "The GitHub repository resource."
  value       = github_repository.this
}

output "tfe_registry_module" {
  description = "The private registry module resource."
  value       = tfe_registry_module.this
}

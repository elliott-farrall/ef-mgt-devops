output "workspace_ids" {
  description = "Workspace IDs keyed by workspace name."
  value       = { for k, w in tfe_workspace.registry : k => w.id }
}

output "project_ids" {
  value = { for k, p in tfe_project.planes : k => p.id }
}

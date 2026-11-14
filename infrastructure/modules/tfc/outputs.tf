output "workspace_id" {
  value = tfe_workspace.this.id
}

output "project_ids" {
  value = { for k, p in tfe_project.planes : k => p.id }
}

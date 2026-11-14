output "folder_ids" {
  description = "Folder IDs (numeric) keyed by name."
  value       = { for k, f in google_folder.tree : k => f.folder_id }
}

output "project_ids" {
  description = "Project IDs keyed by name."
  value       = { for k, p in google_project.platform : k => p.project_id }
}

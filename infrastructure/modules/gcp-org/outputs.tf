output "folder_ids" {
  description = "Folder IDs keyed by display name, ef-root included."
  value = merge(
    { ef-root = google_folder.ef_root.name },
    { for k, f in google_folder.tree : k => f.name },
  )
}

output "project_ids" {
  description = "Platform project IDs keyed by project id."
  value       = { for k, p in google_project.platform : k => p.project_id }
}

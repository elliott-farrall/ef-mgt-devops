output "folder_ids" {
  description = "Folder IDs keyed by display name, ef-root included."
  value = merge(
    { ef-root = google_folder.ef_root.name },
    { for k, f in google_folder.tree : k => f.name },
  )
}

output "landing_project_id" {
  value = google_project.landing.project_id
}

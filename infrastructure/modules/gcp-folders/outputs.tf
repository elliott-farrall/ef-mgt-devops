output "folder_ids" {
  description = "Numeric folder IDs keyed by name."
  value       = { for k, f in google_folder.tree : k => f.folder_id }
}

output "folder_names" {
  description = "Folder resource names (folders/<ID>) keyed by name."
  value       = { for k, f in google_folder.tree : k => f.name }
}

output "repository_ids" {
  description = "Repository slugs keyed by name."
  value       = { for k, r in github_repository.registry : k => r.id }
}

output "repository_node_ids" {
  value = { for k, r in github_repository.registry : k => r.node_id }
}

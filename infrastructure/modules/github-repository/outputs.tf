output "github_repository" {
  description = "The repository resource."
  value       = github_repository.this
}

output "github_branch_protection" {
  description = "Main branch protection policy."
  value       = github_branch_protection.this
}

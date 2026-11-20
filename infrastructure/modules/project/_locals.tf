locals {
  labels = {
    environment = var.environment
    managed_by  = "terraform"
    repository  = var.repo
  }
  queue_all_runs = var.run_after_workspace_id == null
}

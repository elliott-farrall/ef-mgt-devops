resource "tfe_run_trigger" "this" {
  workspace_id  = var.workspace_id
  sourceable_id = var.sourceable_id
}

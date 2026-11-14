# -- tfe_project.this: TFE project container for workspaces --
resource "tfe_project" "this" {
  name = var.name
}

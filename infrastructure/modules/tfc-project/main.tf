resource "tfe_project" "this" {
  name         = var.name
  organization = var.organisation
}

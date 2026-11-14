# -- data.tfe_github_app_installation.this: resolves GitHub App installation ID by name --
data "tfe_github_app_installation" "this" {
  name = var.github_app_installation
}

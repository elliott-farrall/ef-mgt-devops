module "repository" {
  source = "../repository"

  repo          = var.repo
  description   = var.description
  settings      = var.settings
  protection    = var.protection
  status_checks = local.status_checks
  pages         = var.pages
  cname         = var.cname
  zone          = var.zone
  github_owner  = var.github_owner
}

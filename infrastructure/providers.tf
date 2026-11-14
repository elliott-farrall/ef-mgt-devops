# -- provider google --
provider "google" {
  region = local.config.organisation.gcp.region
}

# -- provider tfe --
provider "tfe" {
  hostname     = local.config.organisation.tfe.hostname
  organization = local.config.organisation.tfe.organisation
}


# -- provider github --
provider "github" {
  owner = local.config.organisation.gh.owner
}

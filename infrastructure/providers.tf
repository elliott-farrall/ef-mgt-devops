provider "google" {
  region = local.config.organisation.gcp.region
}

provider "tfe" {
  hostname     = try(local.config.organisation.tfe.hostname, "app.terraform.io")
  organization = local.config.organisation.tfe.organisation
}


provider "github" {
  owner = local.config.organisation.github.owner
}

provider "google" {
  region = local.config.gcp.region
}

provider "tfe" {
  hostname     = try(local.config.tfc.hostname, "app.terraform.io")
  organization = local.config.tfc.organisation
}


provider "github" {
  owner = local.config.gh.owner
}

provider "google" {
  region = local.config.organisation.gcp.region
}

provider "tfe" {
  hostname     = local.config.organisation.tfe.hostname
  organization = local.config.organisation.tfe.organisation
}

provider "github" {
  owner = local.config.organisation.gh.owner
}

provider "cloudflare" {
}

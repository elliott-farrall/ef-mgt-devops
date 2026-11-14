provider "google" {
  region = local.gcp_region
}

provider "tfe" {
  hostname = local.tfc_hostname
}

provider "cloudflare" {
}

provider "github" {
  owner = local.gh.owner
}

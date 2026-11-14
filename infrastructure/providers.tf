provider "google" {
  region = local.config.gcp.region
}

provider "tfe" {
  hostname = try(local.config.tfc.hostname, "app.terraform.io")
}

provider "cloudflare" {
}

provider "github" {
  owner = local.config.gh.owner
}

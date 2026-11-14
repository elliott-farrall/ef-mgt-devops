provider "google" {
  project = local.landing_project
  region  = local.gcp_region
}

provider "tfe" {
  hostname = local.tfc_hostname
}

provider "cloudflare" {
  # Auth via CLOUDFLARE_API_TOKEN env var (TFC sensitive variable in steady
  # state); account/zone scope lives on the resources.
}

provider "github" {
  owner = local.gh.owner
  # Auth via GITHUB_TOKEN env var (TFC sensitive variable in steady state).
}

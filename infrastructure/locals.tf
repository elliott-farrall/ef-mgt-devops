locals {
  env_dir = "${path.root}/../environments/${var.environment}"

  # One file per platform concern; alphabetical merge keeps this order stable.
  config = merge([for f in sort(fileset(local.env_dir, "*.yaml")) : yamldecode(file("${local.env_dir}/${f}"))]...)

  gcp = local.config.gcp
  tfc = local.config.tfc
  cf  = local.config.cf
  gh  = local.config.gh

  repository      = basename(abspath("${path.root}/.."))
  landing_project = local.gcp.landing_project
  gcp_region      = local.gcp.region
  tfc_hostname    = local.tfc.hostname

  tfc_plane_project = "ef-${var.environment}"

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    repository  = local.repository
    tfc_project = local.tfc_plane_project
  }
}

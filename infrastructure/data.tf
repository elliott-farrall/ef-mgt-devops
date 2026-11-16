# -- data.google_organization: looks up GCP organisation by domain --
data "google_organization" "ef" {
  domain = local.config.organisation.gcp.domain
}

# -- data.google_project.landing: numeric ID of the platform home --
data "google_project" "landing" {
  project_id = local.google_default_project
}

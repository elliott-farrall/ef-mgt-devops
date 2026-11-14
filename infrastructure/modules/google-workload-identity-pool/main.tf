# -- google_iam_workload_identity_pool.this: WIF pool for TFC token exchange --
resource "google_iam_workload_identity_pool" "this" {
  workload_identity_pool_id = var.name
  project                   = var.project
}

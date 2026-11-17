resource "google_dns_managed_zone" "this" {
  name     = var.name
  dns_name = "${var.domain}."
  project  = var.project_id

  lifecycle {
    prevent_destroy = true
  }
}

locals {
  record_sets = {
    for r in var.records : "${r.name}|${r.type}" => {
      name    = r.name == var.domain ? "${var.domain}." : "${r.name}.${var.domain}."
      type    = r.type
      ttl     = r.ttl
      rrdatas = r.type == "TXT" ? [for v in r.records : "\"${v}\""] : r.records
    }
  }
}

resource "google_dns_record_set" "this" {
  for_each = local.record_sets

  managed_zone = google_dns_managed_zone.this.name
  project      = var.project_id
  name         = each.value.name
  type         = each.value.type
  ttl          = each.value.ttl
  rrdatas      = each.value.rrdatas
}

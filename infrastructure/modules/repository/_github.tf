resource "github_repository" "this" {
  name        = local.repository.name
  description = local.repository.description

  visibility             = local.repository.visibility
  has_issues             = local.repository.has_issues
  has_projects           = local.repository.has_projects
  has_wiki               = local.repository.has_wiki
  allow_merge_commit     = local.repository.allow_merge_commit
  allow_squash_merge     = local.repository.allow_squash_merge
  allow_rebase_merge     = local.repository.allow_rebase_merge
  allow_auto_merge       = local.repository.allow_auto_merge
  delete_branch_on_merge = local.repository.delete_branch_on_merge

  lifecycle {
    prevent_destroy = true
  }
}

resource "github_repository_ruleset" "enforcement" {
  name        = "main-enforcement"
  repository  = github_repository.this.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/heads/main"]
      exclude = []
    }
  }

  rules {
    required_linear_history = true
    non_fast_forward        = true
    deletion                = true

    required_status_checks {
      strict_required_status_checks_policy = true

      dynamic "required_check" {
        for_each = local.protection.status_checks
        content {
          context = required_check.value
        }
      }
    }
  }
}

resource "github_repository_ruleset" "review" {
  name        = "main-review"
  repository  = github_repository.this.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/heads/main"]
      exclude = []
    }
  }

  bypass_actors {
    actor_type  = "RepositoryRole"
    actor_id    = 5
    bypass_mode = "pull_request"
  }

  rules {
    pull_request {
      required_approving_review_count   = local.protection.required_approving_review_count
      required_review_thread_resolution = local.protection.require_conversation_resolution
      dismiss_stale_reviews_on_push     = local.protection.dismiss_stale_reviews
      allowed_merge_methods             = ["squash"]
    }
  }
}

resource "github_repository_vulnerability_alerts" "this" {
  repository = github_repository.this.name
}

resource "github_repository_pages" "this" {

  depends_on = [cloudflare_dns_record.this]
  count      = var.pages ? 1 : 0

  repository     = github_repository.this.name
  build_type     = "workflow"
  cname          = var.cname
  https_enforced = true
}

resource "cloudflare_dns_record" "this" {
  count = var.pages ? 1 : 0

  zone_id = data.cloudflare_zone.this.id
  name    = var.cname
  type    = "CNAME"
  content = "${var.github_owner}.github.io"
  ttl     = 3600
  proxied = false
}

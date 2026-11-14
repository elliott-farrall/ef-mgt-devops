#!/usr/bin/env bash
# Bootstrap orchestrator: preflight -> seed scripts -> (push scaffold) -> import.
# Usage: scripts/bootstrap.sh [--with-import]
# Steps 5 (TFC run proves no-diff) and 6 (close out) are manual — runbook.
source "$(dirname "$0")/bootstrap/lib.sh"

require_env EF_ORG_ID EF_BILLING_ACCOUNT TFC_TOKEN CF_API_TOKEN CF_ACCOUNT_ID

log "preflight: tools"
for t in gcloud terraform jq curl git; do
  command -v "$t" >/dev/null || die "$t not found on PATH"
done

log "preflight: inventory placeholders"
[[ "$(inventory_get organization_id)" == "$EF_ORG_ID" ]] || warn "inventory organization_id differs from EF_ORG_ID"

"$REPO_ROOT/scripts/bootstrap/01-gcp.sh"
"$REPO_ROOT/scripts/bootstrap/02-tfc.sh"
"$REPO_ROOT/scripts/bootstrap/03-cloudflare.sh"

log "seed complete. Commit inventory.yaml, push this branch, then re-run with --with-import."
if [[ "${1:-}" == "--with-import" ]]; then
  "$REPO_ROOT/scripts/bootstrap/04-import.sh"
fi

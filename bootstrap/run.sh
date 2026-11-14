#!/usr/bin/env bash
source "$(dirname "$0")/00-lib.sh"

require_env EF_ORG_ID EF_BILLING_ACCOUNT TFC_TOKEN CF_API_TOKEN CF_ACCOUNT_ID GITHUB_TOKEN

log "preflight: tools"
for t in gcloud terraform jq curl git; do
  command -v "$t" >/dev/null || die "$t not found on PATH"
done

"$REPO_ROOT/bootstrap/01-gcp.sh"
"$REPO_ROOT/bootstrap/02-tfc.sh"
"$REPO_ROOT/bootstrap/03-cf.sh"
"$REPO_ROOT/bootstrap/04-import.sh"

log "seed + adopt complete. Commit inventory.yaml, open the PR for Steps 5–6;"
log "after the merge, run bootstrap/05-cleanup.sh to close out."

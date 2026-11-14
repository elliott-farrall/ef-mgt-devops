#!/usr/bin/env bash
source "$(dirname "$0")/00-lib.sh"
require_env EF_ORG_ID TFC_TOKEN

LANDING="$(inventory_get landing_project)"
[[ -n "$LANDING" ]] || die "landing_project missing from inventory — run Steps 1–4 first"

log "closing out bootstrap"

if gcloud iam service-accounts list --project="$LANDING" --format="value(email)" \
   | grep -q "sa-adm-bootstrap@"; then
  log "deleting sa-adm-bootstrap"
  gcloud iam service-accounts delete "sa-adm-bootstrap@$LANDING.iam.gserviceaccount.com" --quiet
else
  warn "sa-adm-bootstrap already absent"
fi

# Inventory values now live in Terraform state; the file exists only to hand
# IDs from the seed scripts to 04-import.sh.
git -C "$REPO_ROOT" rm -q bootstrap/inventory.yaml

log "commit the removal, then finish the manual checklist:"
cat <<'EOF'
  [ ] revoke the TFC user token, the Cloudflare seed token, and the bootstrap GitHub PAT
  [ ] enable weekly drift checks on the ef-mgt-devops workspace
  [ ] git tag bootstrap-v1.0 && git push --tags
EOF

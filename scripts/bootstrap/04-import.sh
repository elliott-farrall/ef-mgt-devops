#!/usr/bin/env bash
# Step 4 — Adopt via import: init against the TFC workspace and import every
# resource the seed scripts created (IDs read from inventory.yaml).
# Run AFTER pushing this scaffold, BEFORE the first TFC run.
source "$(dirname "$0")/lib.sh"
require_env TFC_TOKEN

cd "$REPO_ROOT/infrastructure"

export TF_ADDRESS="https://app.terraform.io"
export TF_CREDENTIALS="env"
export TF_HTTP_USERNAME="token"
export TF_HTTP_PASSWORD="$TFC_TOKEN"
export TF_WORKSPACE="${EF_TFC_WORKSPACE:-ef-mgt-devops}"
export TF_VAR_environment="mgt"

log "init against remote workspace $TF_WORKSPACE"
terraform init -backend-config="organization=${EF_TFC_ORG:-elliott-farrall}"

# Import list: terraform address -> inventory key. Addresses must match the
# scaffolded code exactly; verify against docs/bootstrap.md before a real run.
import_one() {
  local addr="$1" id="$2"
  [[ -n "$id" ]] || { warn "skipping $addr — inventory key empty"; return 0; }
  log "import $addr <- $id"
  terraform import -input=false "$addr" "$id" || die "import failed for $addr"
}

R="google_folder"
import_one "$R.ef_root"            "folders/$(inventory_get folder_ef-root)"
for f in ef-mgt ef-hub ef-app ef-dev ef-pre ef-prd; do
  import_one "$R.tree[\"$f\"]" "folders/$(inventory_get "folder_${f}")"
done
import_one "google_project.landing" "$(inventory_get landing_project)"

T="module.tfc"
for p in ef-mgt ef-hub ef-app; do
  import_one "$T.tfe_project.planes[\"$p\"]" "$(inventory_get "tfc_project_${p}")"
done
import_one "$T.tfe_workspace.this" "$(inventory_get tfc_workspace)"
import_one "$T.tfe_workspace_settings.this" "$(inventory_get tfc_workspace)"

import_one "module.cloudflare.cloudflare_zone.apex" "$(inventory_get cf_zone_apex)"

# TODO: extend the list when the IAM/WIF/orgpolicy resources land in the
# modules (they import with composite addresses — see docs/bootstrap.md).

log "import complete — now prove the loop: terraform plan must show no diff"

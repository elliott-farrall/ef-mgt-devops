#!/usr/bin/env bash
source "$(dirname "$0")/00-lib.sh"
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

import_one() {
  local addr="$1" id="$2"
  [[ -n "$id" && "$id" != "folders/" ]] || { warn "skipping $addr — inventory key empty"; return 0; }
  log "import $addr <- $id"
  terraform import -input=false "$addr" "$id" || die "import failed for $addr"
}

G="module.gcp_org"
import_one "$G.google_folder.tree[\"ef-root\"]" "folders/$(inventory_get folder_ef-root)"
for f in ef-mgt ef-hub ef-app ef-dev ef-pre ef-prd; do
  import_one "$G.google_folder.tree[\"$f\"]" "folders/$(inventory_get "folder_${f}")"
done
import_one "$G.google_project.platform[\"ef-mgt-devops\"]" "$(inventory_get landing_project)"
import_one "$G.google_service_account.platform[\"sa-mgt-tfc\"]" "$(inventory_get sa_mgt_tfc)"
for sa in sa-adm-tfc sa-hub-tfc sa-dev-tfc sa-pre-tfc sa-prd-tfc; do
  import_one "$G.google_service_account.platform[\"$sa\"]" "$(inventory_get "sa_${sa//-/_}")"
done

T="module.tfc"
for p in ef-mgt ef-hub ef-app; do
  import_one "$T.tfe_project.planes[\"$p\"]" "$(inventory_get "tfc_project_${p}")"
done
import_one "$T.tfe_workspace.registry[\"ef-mgt-devops\"]" "$(inventory_get tfc_workspace)"
import_one "$T.tfe_workspace_settings.registry[\"ef-mgt-devops\"]" "$(inventory_get tfc_workspace)"

import_one "module.cf.cloudflare_zone.registry[\"elliott-farrall.phd\"]" "$(inventory_get cf_zone_apex)"
import_one "module.gh.github_repository.registry[\"ef-mgt-devops\"]" "$(inventory_get gh_repository)"


log "import complete — now prove the loop: terraform plan must show no diff"

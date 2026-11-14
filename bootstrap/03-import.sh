#!/usr/bin/env bash
source "$(dirname "$0")/00-lib.sh"
require_env TFC_TOKEN

cd "$REPO_ROOT/infrastructure" || exit 1

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

for f in ef-root ef-mgt ef-hub ef-app ef-dev ef-pre ef-prd; do
  import_one "module.google-folder.google_folder.tree[\"$f\"]" "folders/$(inventory_get "folder_${f}")"
done
import_one "module.google-project[\"ef-mgt-devops\"].google_project.this" "$(inventory_get landing_project)"

for sa in sa-mgt-tfc sa-hub-tfc sa-dev-tfc sa-pre-tfc sa-prd-tfc; do
  import_one "module.google-service-account[\"$sa\"].google_service_account.this" "$(inventory_get "sa_${sa//-/_}")"
done

for p in ef-mgt ef-hub; do
  import_one "module.tfe-project[\"$p\"].tfe_project.this" "$(inventory_get "tfe_project_${p}")"
done
import_one "module.tfe-workspace[\"ef-mgt-devops\"].tfe_workspace.this" "$(inventory_get tfe_workspace)"
import_one "module.tfe-workspace[\"ef-mgt-devops\"].tfe_workspace_settings.this" "$(inventory_get tfe_workspace)"

import_one "module.github-repository[\"ef-mgt-devops\"].github_repository.this" "$(inventory_get github_repository)"


log "import complete — now prove the loop: terraform plan must show no diff"

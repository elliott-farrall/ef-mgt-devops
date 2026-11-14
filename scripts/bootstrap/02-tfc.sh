#!/usr/bin/env bash
# Step 2 — Seed Terraform Cloud: projects (ef-mgt/ef-hub/ef-app), global
# variable set, and the ef-mgt-devops workspace (environment = mgt).
# Get-or-create idempotent. Requires a TFC user API token (TFC_TOKEN).
source "$(dirname "$0")/lib.sh"
require_env TFC_TOKEN

ORG="${EF_TFC_ORG:-elliott-farrall}"
API="https://app.terraform.io/api/v2"
HDR=(-H "Authorization: Bearer $TFC_TOKEN" -H "Content-Type: application/vnd.api+json")

tfc() { curl -sf "${HDR[@]}" "$@"; }

org_id() { tfc "$API/organizations/$ORG" | jq -r '.data.id'; }
log "seeding Terraform Cloud organisation $ORG"

ORG_ID="$(org_id)"

ensure_project() { # name
  local name="$1" id
  id="$(tfc "$API/organizations/$ORG/projects?search[name]=$name" \
        | jq -r --arg n "$name" '.data[] | select(.attributes.name==$n) | .id' | head -n1)"
  if [[ -n "$id" ]]; then
    log "project $name already exists ($id)"
  else
    log "creating project $name"
    id="$(tfc -X POST "$API/projects" \
          -d "$(jq -n --arg n "$name" --arg o "$ORG_ID" '{data:{type:"projects",attributes:{name:$n,settings:{execution-mode:"remote"},auto-destroy-activity-duration:-1},relationships:{organization:{data:{type:"organizations",id:$o}}}}}')" \
          | jq -r '.data.id')"
  fi
  inventory_set "tfc_project_${name}" "$id"
}

for p in ef-mgt ef-hub ef-app; do ensure_project "$p"; done

# TODO (implement during bootstrap prep, same pattern):
#  [ ] global variable set "ef-global": organization_id, billing_account,
#      cf_account_id (non-sensitive) applied to all future workspaces.
#  [ ] workspace ef-mgt-devops in project ef-mgt: environment = mgt,
#      working directory infrastructure/, VCS left detached until Step 5.
#      Record tfc_varset_global + tfc_workspace in inventory.
#  [ ] sensitive variables (CLOUDFLARE_API_TOKEN) created manually in the UI
#      or via API — value never passes through this repository.

log "done — commit the updated inventory.yaml"

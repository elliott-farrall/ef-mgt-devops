#!/usr/bin/env bash
source "$(dirname "$0")/00-lib.sh"
require_env TFC_TOKEN

ORG="${EF_TFC_ORG:-elliott-farrall}"
API="https://app.terraform.io/api/v2"
HDR=(-H "Authorization: Bearer $TFC_TOKEN" -H "Content-Type: application/vnd.api+json")

tfc() { curl -sf "${HDR[@]}" "$@"; }

log "seeding Terraform Cloud organisation $ORG"

ORG_ID="$(tfc "$API/organizations/$ORG" | jq -r '.data.id')"

ensure_project() {
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


log "done — commit the updated inventory.yaml"

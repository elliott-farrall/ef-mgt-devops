#!/usr/bin/env bash
source "$(dirname "$0")/00-lib.sh"
require_env EF_BILLING_ACCOUNT

ORG="${EF_ORG_ID:-}"
if [[ -z "$ORG" ]]; then
  ORG_DOMAIN="${EF_ORG_DOMAIN:-elliott-farrall.phd}"
  ORG="$(gcloud organizations list --filter="display_name=${ORG_DOMAIN}" --format='value(name)' | head -n1)"
fi
[[ -n "$ORG" ]] || die "organisation not resolved — set EF_ORG_ID or EF_ORG_DOMAIN"
log "seeding GCP for organisation $ORG"

folder_id() {
  gcloud resource-manager folders list --organization="$ORG" \
    --filter="displayName=$1" --format="value(name)" 2>/dev/null | head -n1
}

ensure_folder() {
  local name="$1" parent="$2" existing
  existing="$(folder_id "$name")"
  if [[ -n "$existing" ]]; then
    log "folder $name already exists ($existing)"
  else
    log "creating folder $name under $parent"
    existing="$(gcloud resource-manager folders create \
      --display-name="$name" --parent="$parent" --organization="$ORG" \
      --format="value(name)")"
  fi
  inventory_set "folder_${name}" "${existing##*/}"
}

ensure_folder "ef-root" "organizations/$ORG"
ROOT="folders/$(inventory_get folder_ef-root)"
for f in ef-mgt ef-hub ef-app; do ensure_folder "$f" "$ROOT"; done
APP="folders/$(inventory_get folder_ef-app)"
for f in ef-dev ef-pre ef-prd; do ensure_folder "$f" "$APP"; done


log "done — commit the updated inventory.yaml"

#!/usr/bin/env bash
source "$(dirname "$0")/00-lib.sh"
require_env CF_API_TOKEN CF_ACCOUNT_ID

API="https://api.cloudflare.com/client/v4"
HDR=(-H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json")
ZONE="${EF_APEX_ZONE:-elliott-farrall.phd}"

cf() { curl -sf "${HDR[@]}" "$@"; }

log "seeding Cloudflare zone $ZONE"

zone_id="$(cf "$API/zones?name=$ZONE" | jq -r '.result[0].id // empty')"
if [[ -n "$zone_id" ]]; then
  log "zone already exists ($zone_id)"
else
  log "creating zone $ZONE"
  zone_id="$(cf -X POST "$API/zones" \
    -d "$(jq -n --arg n "$ZONE" --arg a "$CF_ACCOUNT_ID" '{name:$n,account:{id:$a}}')" \
    | jq -r '.result.id')"
fi
inventory_set "cf_zone_apex" "$zone_id"


log "done — commit the updated inventory.yaml"

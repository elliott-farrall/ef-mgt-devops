#!/usr/bin/env bash
# Step 3 — Seed Cloudflare: apex zone elliott-farrall.phd + a least-privilege
# API token scoped to it (for the TFC workspace). Get-or-create idempotent.
source "$(dirname "$0")/lib.sh"
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

# TODO (implement during bootstrap prep):
#  [ ] create scoped token "ef-tfc-mgt-devops": permissions Zone.DNS:Edit +
#      Zone.Zone:Read, resources Zone scoped to $zone_id ONLY. Value goes
#      straight into the TFC sensitive variable — never into a file here.
#  [ ] record nameservers for the registrar check in docs/bootstrap.md output.

log "done — commit the updated inventory.yaml"

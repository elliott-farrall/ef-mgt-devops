#!/usr/bin/env bash
# Step 1 — Seed GCP: landing project, folder tree, org policies, billing link,
# service accounts (sa-mgt-tfc, sa-adm-bootstrap), TFC workload identity pool.
# Get-or-create idempotent: safe to re-run. Creates and records only.
source "$(dirname "$0")/lib.sh"
require_env EF_ORG_ID EF_BILLING_ACCOUNT

ORG="$EF_ORG_ID"
log "seeding GCP for organisation $ORG"

folder_id() { # name -> "folders/123..." or empty
  gcloud resource-manager folders list --organization="$ORG" \
    --filter="displayName=$1" --format="value(name)" 2>/dev/null | head -n1
}

ensure_folder() { # name parent-resource-id
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

# TODO (implement during bootstrap prep, same get-or-create pattern):
#  [ ] landing project ef-mgt-devops under ef-mgt, linked to $EF_BILLING_ACCOUNT,
#      standard labels applied; enable APIs: cloudresourcemanager, iamcredentials,
#      orgpolicy, serviceusage (project-level enablement is fine here).
#  [ ] service accounts sa-mgt-tfc + sa-adm-bootstrap in the landing project.
#  [ ] IAM: role bindings for sa-mgt-tfc at folder ef-mgt (folderManager,
#      orgAdministrator-equivalent scoped set); sa-adm-bootstrap at org level
#      (deleted at Step 6).
#  [ ] Workload identity pool + provider for Terraform Cloud (attribute:
#      assertion.vcs/repo == elliott-farrall/ef-mgt-devops).
#  [ ] Org policies: constraints/required.labels, prevent project deletion,
#      allowed regions [europe-west2, us-central1] — names per design §3.3.

log "done — commit the updated inventory.yaml"

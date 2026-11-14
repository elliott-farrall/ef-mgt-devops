#!/usr/bin/env bash
set -euo pipefail

# ── Bootstrap: EF platform bring-up ────────────────────────────────
# Creates seed resources that Terraform cannot create itself (folders,
# billing link, landing project). Then imports them into state.
# After this, the standard deployment workflow takes over.
# ──────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_DIR="$REPO_ROOT/environments/mgt"

log()  { printf '\033[1;36m[ef]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[ef] warn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[ef] fatal:\033[0m %s\n' "$*" >&2; exit 1; }

# ── Read config from YAML ─────────────────────────────────────────

GCP_DOMAIN=$(yq '.organisation.gcp.domain' "$ENV_DIR/organisation.yaml")
TFC_ORG=$(yq '.organisation.tfe.organisation' "$ENV_DIR/organisation.yaml")
TFC_HOSTNAME=$(yq '.organisation.tfe.hostname' "$ENV_DIR/organisation.yaml")

[[ -n "$GCP_DOMAIN" ]] || die "gcp domain not found in $ENV_DIR/organisation.yaml"
[[ -n "$TFC_ORG" ]] || die "TFC organisation not found in $ENV_DIR/organisation.yaml"
[[ -n "$TFC_HOSTNAME" ]] || die "TFC hostname not found in $ENV_DIR/organisation.yaml"

# ── Prerequisites ──────────────────────────────────────────────────

[[ -n "${TFC_TOKEN:-}" ]] || die "Required environment variable TFC_TOKEN is unset."

for t in gcloud terraform jq curl git tfc; do
  command -v "$t" >/dev/null || die "$t not found on PATH"
done

# Set TFC auth for both Terraform backend and tfccli.
# tfccli uses TF_TOKEN_<sanitized_host> per Terraform CLI conventions.
export TF_TOKEN_APP_TERRAFORM_IO="${TFC_TOKEN:-}"

# ── Read billing account from config ───────────────────────────────

BILLING_ACCOUNT=$(yq '.billing.billing_account_id' "$ENV_DIR/billing.yaml")
[[ -n "$BILLING_ACCOUNT" ]] || die "billing_account_id not found in $ENV_DIR/billing.yaml"

# ── Step 1: Seed GCP ───────────────────────────────────────────────

log "seeding GCP for organisation $GCP_DOMAIN"

ORG="$(gcloud organizations list --filter="display_name=${GCP_DOMAIN}" --format='value(name)' | head -n1)"
[[ -n "$ORG" ]] || die "organisation not resolved — set EF_ORG_ID or EF_GCP_DOMAIN"

LANDING="ef-mgt-devops"

# Create ef-root folder if it does not exist
ROOT_FOLDER_NAME="$(gcloud resource-manager folders list --organization="$ORG" \
  --filter="displayName=ef-root" --format="value(name)" 2>/dev/null | head -n1)"
if [[ -n "$ROOT_FOLDER_NAME" ]]; then
  log "folder ef-root already exists ($ROOT_FOLDER_NAME)"
else
  log "creating folder ef-root under organizations/$ORG"
  ROOT_FOLDER_NAME="$(gcloud resource-manager folders create \
    --display-name=ef-root --parent="organizations/$ORG" --organization="$ORG" \
    --format="value(name)")"
fi
ROOT="folders/${ROOT_FOLDER_NAME#/}"

# Create ef-mgt-devops project if it does not exist
if gcloud projects describe "$LANDING" >/dev/null 2>&1; then
  log "project $LANDING already exists"
else
  log "creating project $LANDING"
  gcloud projects create "$LANDING" \
    --folder="$ROOT" \
    --billing-account="$BILLING_ACCOUNT" \
    --set-as-default
fi

log "enabling APIs on $LANDING"
gcloud services enable \
  iam.googleapis.com serviceusage.googleapis.com cloudbilling.googleapis.com \
  dns.googleapis.com compute.googleapis.com \
  --project="$LANDING"

BOOT_SA="sa-adm-bootstrap@$LANDING.iam.gserviceaccount.com"
if gcloud iam service-accounts list --project="$LANDING" --format="value(email)" \
   | grep -q "sa-adm-bootstrap@"; then
  log "sa-adm-bootstrap already exists"
else
  log "creating sa-adm-bootstrap"
  gcloud iam service-accounts create "sa-adm-bootstrap" \
    --display-name="Bootstrap admin" \
    --project="$LANDING"
fi

# ── Step 2: Seed Terraform Cloud ───────────────────────────────────

TFC_OPTS="--address https://${TFC_HOSTNAME} --org ${TFC_ORG} --output-format json"

# Resolve organisation ID via tfc
ORG_ID="$(tfc organizations get --name "$TFC_ORG" ${TFC_OPTS} | jq -r '.id')"

# Create ef-mgt TFC project if it does not exist
LANDING_PROJ="$(tfc projects list ${TFC_OPTS} | jq -r 'select(.name=="ef-mgt") | .id' | head -n1)"
if [[ -z "$LANDING_PROJ" ]]; then
  log "creating project ef-mgt"
  LANDING_PROJ="$(tfc projects create --name ef-mgt ${TFC_OPTS} | jq -r '.id')"
  log "project ef-mgt → $LANDING_PROJ"
else
  log "project ef-mgt already exists ($LANDING_PROJ)"
fi

# Create ef-mgt-devops workspace if it does not exist
LANDING_WS="ef-mgt-devops"
ws_id="$(tfc workspaces list ${TFC_OPTS} --project-id "$LANDING_PROJ" \
         | jq -r "select(.name==\"$LANDING_WS\") | .id" | head -n1)"
if [[ -n "$ws_id" ]]; then
  log "workspace $LANDING_WS already exists ($ws_id)"
else
  log "creating workspace $LANDING_WS in project ef-mgt"
  ws_id="$(tfc workspaces create --name "$LANDING_WS" --project-id "$LANDING_PROJ" ${TFC_OPTS} \
           | jq -r '.id')"
  log "workspace $LANDING_WS → $ws_id"
fi

# ── Step 3: Adopt via import ───────────────────────────────────────

cd "$REPO_ROOT/infrastructure" || exit 1

export TF_ADDRESS="https://app.terraform.io"
export TF_CREDENTIALS="env"
export TF_HTTP_USERNAME="token"
export TF_HTTP_PASSWORD="$TFC_TOKEN"
export TF_WORKSPACE="${EF_TFC_WORKSPACE:-ef-mgt-devops}"
export TF_VAR_environment="mgt"

log "init against remote workspace $TF_WORKSPACE"
terraform init -backend-config="organization=$TFC_ORG"

import_one() {
  local addr="$1" id="$2"
  [[ -n "$id" && "$id" != "folders/" ]] || { warn "skipping $addr — ID empty"; return 0; }
  log "import $addr <- $id"
  terraform import -input=false "$addr" "$id" || die "import failed for $addr"
}

# Folders
for f in ef-root ef-mgt; do
  fid="$(gcloud resource-manager folders list --organization="$ORG" \
         --filter="displayName=$f" --format="value(name)" 2>/dev/null | head -n1)"
  import_one "module.google-folder.google_folder.tree[\"$f\"]" "folders/${fid}"
done

# Landing project
proj_num="$(gcloud projects describe "$LANDING" --format='value(projectNumber)' 2>/dev/null | head -n1)"
[[ -n "$proj_num" ]] || die "project $LANDING not found"
import_one "module.google-project[\"$LANDING\"].google_project.this" "$proj_num"

# TFC project + workspace
pid="$(tfc projects list ${TFC_OPTS} | jq -r 'select(.name=="ef-mgt") | .id' | head -n1)"
[[ -n "$pid" ]] || die "TFC project ef-mgt not found"
import_one "module.tfe-project[\"ef-mgt\"].tfe_project.this" "prj-$pid"

ws_id="$(tfc workspaces list ${TFC_OPTS} --project-id "$LANDING_PROJ" \
         | jq -r "select(.name==\"$LANDING_WS\") | .id" | head -n1)"
[[ -n "$ws_id" ]] || die "workspace $LANDING_WS not found"
import_one "module.tfe-workspace[\"$LANDING_WS\"].tfe_workspace.this" "$ws_id"
import_one "module.tfe-workspace[\"$LANDING_WS\"].tfe_workspace_settings.this" "$ws_id"

# GitHub repo
import_one "module.github-repository[\"$LANDING\"].github_repository.this" "$LANDING"


log "import complete — now prove the loop: terraform plan must show no diff"

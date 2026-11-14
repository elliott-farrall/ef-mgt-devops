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
GCP_BILLING_ACCOUNT=$(yq '.billing.billing_account_id' "$ENV_DIR/billing.yaml")
TFC_ORG=$(yq '.organisation.tfe.organisation' "$ENV_DIR/organisation.yaml")
TFC_HOSTNAME=$(yq '.organisation.tfe.hostname' "$ENV_DIR/organisation.yaml")
GH_OWNER=$(yq '.organisation.gh.owner' "$ENV_DIR/organisation.yaml")

GCP_ENV_NAME=$(yq '.environments[] | select(.projects[]?.default == true) | .name' "$ENV_DIR/environments.yaml")
GCP_PROJECT_SUFFIX=$(yq '.environments[] | select(.projects[]?.default == true) | .projects[] | select(.default == true) | .name' "$ENV_DIR/environments.yaml")

[[ -n "$GCP_DOMAIN" ]] || die "gcp domain not found in $ENV_DIR/organisation.yaml"
[[ -n "$GCP_BILLING_ACCOUNT" ]] || die "billing account id not found in $ENV_DIR/billing.yaml"
[[ -n "$TFC_ORG" ]] || die "TFC organisation not found in $ENV_DIR/organisation.yaml"
[[ -n "$TFC_HOSTNAME" ]] || die "TFC hostname not found in $ENV_DIR/organisation.yaml"
[[ -n "$GH_OWNER" ]] || die "github owner not found in $ENV_DIR/organisation.yaml"
[[ -n "$GCP_ENV_NAME" && -n "$GCP_PROJECT_SUFFIX" ]] || die "default project not found in $ENV_DIR/environments.yaml"

GCP_DEFAULT_PROJECT="ef-${GCP_ENV_NAME}-${GCP_PROJECT_SUFFIX}"

# ── Prerequisites ──────────────────────────────────────────────────

for t in gcloud terraform jq curl git tfc; do
  command -v "$t" >/dev/null || die "$t not found on PATH"
done

# tfccli and Terraform backend both use TF_TOKEN_<host> per
# Terraform CLI conventions.
export TF_TOKEN_APP_TERRAFORM_IO

# ── Step 1: Resolve organisation ───────────────────────────────────

GCP_ORG="$(gcloud organizations list --filter="display_name=${GCP_DOMAIN}" --format='value(name)' | head -n1)"
[[ -n "$GCP_ORG" ]] || die "organisation not resolved — set EF_ORG_ID or EF_GCP_DOMAIN"

# ── Step 2: Create ef-root folder ──────────────────────────────────

GCP_ROOT_FOLDER_ID="$(gcloud resource-manager folders list --organization="$GCP_ORG" \
  --filter="displayName=ef-root" --format="value(name)" 2>/dev/null | head -n1)"
if [[ -n "$GCP_ROOT_FOLDER_ID" ]]; then
  log "folder ef-root already exists ($GCP_ROOT_FOLDER_ID)"
else
  log "creating folder ef-root under organizations/$GCP_ORG"
  GCP_ROOT_FOLDER_ID="$(gcloud resource-manager folders create \
    --display-name=ef-root --parent="organizations/$GCP_ORG" --organization="$GCP_ORG" \
    --format="value(name)")"
fi

# ── Step 3: Create ef-mgt folder ───────────────────────────────────

GCP_MGT_FOLDER_ID="$(gcloud resource-manager folders list --organization="$GCP_ORG" \
  --filter="displayName=ef-mgt" --format="value(name)" 2>/dev/null | head -n1)"
if [[ -n "$GCP_MGT_FOLDER_ID" ]]; then
  log "folder ef-mgt already exists ($GCP_MGT_FOLDER_ID)"
else
  log "creating folder ef-mgt under $GCP_ROOT_FOLDER_ID"
  GCP_MGT_FOLDER_ID="$(gcloud resource-manager folders create \
    --display-name=ef-mgt --parent="$GCP_ROOT_FOLDER_ID" --organization="$GCP_ORG" \
    --format="value(name)")"
fi

# ── Step 4: Create landing project ─────────────────────────────────

if gcloud projects describe "$GCP_DEFAULT_PROJECT" >/dev/null 2>&1; then
  log "project $GCP_DEFAULT_PROJECT already exists"
else
  log "creating project $GCP_DEFAULT_PROJECT under $GCP_ROOT_FOLDER_ID"
  gcloud projects create "$GCP_DEFAULT_PROJECT" \
    --folder="$GCP_ROOT_FOLDER_ID" \
    --billing-account="$GCP_BILLING_ACCOUNT" \
    --set-as-default
fi

# ── Step 5: Enable APIs on landing project ─────────────────────────

log "enabling APIs on $GCP_DEFAULT_PROJECT"
gcloud services enable \
  iam.googleapis.com serviceusage.googleapis.com cloudbilling.googleapis.com \
  dns.googleapis.com compute.googleapis.com \
  --project="$GCP_DEFAULT_PROJECT"

# ── Step 6: Create management service account ──────────────────────

SA_EMAIL="sa-mgt-tfc@$GCP_DEFAULT_PROJECT.iam.gserviceaccount.com"
if gcloud iam service-accounts list --project="$GCP_DEFAULT_PROJECT" --format="value(email)" \
   | grep -q "sa-mgt-tfc@"; then
  log "sa-mgt-tfc already exists"
else
  log "creating sa-mgt-tfc"
  gcloud iam service-accounts create "sa-mgt-tfc" \
    --display-name="Management plane" \
    --project="$GCP_DEFAULT_PROJECT"
fi

# ── Step 7: Seed Terraform Cloud ───────────────────────────────────

TFC_OPTS="--address https://${TFC_HOSTNAME} --org ${TFC_ORG} --output-format json"

# 7a. Resolve organisation ID
TFC_ORG_ID="$(tfc organizations get --name "$TFC_ORG" ${TFC_OPTS} | jq -r '.id')"

# 7b. Create ef-mgt TFC project
TFC_LANDING_PROJ="$(tfc projects list ${TFC_OPTS} | jq -r 'select(.name=="ef-mgt") | .id' | head -n1)"
if [[ -z "$TFC_LANDING_PROJ" ]]; then
  log "creating TFC project ef-mgt"
  TFC_LANDING_PROJ="$(tfc projects create --name ef-mgt ${TFC_OPTS} | jq -r '.id')"
else
  log "TFC project ef-mgt already exists ($TFC_LANDING_PROJ)"
fi

# 7c. Create ef-mgt-devops workspace
TFC_LANDING_WS="ef-mgt-devops"
TFC_WSID="$(tfc workspaces list ${TFC_OPTS} --project-id "$TFC_LANDING_PROJ" \
         | jq -r "select(.name==\"$TFC_LANDING_WS\") | .id" | head -n1)"
if [[ -n "$TFC_WSID" ]]; then
  log "workspace $TFC_LANDING_WS already exists ($TFC_WSID)"
else
  log "creating workspace $TFC_LANDING_WS in project ef-mgt"
  TFC_WSID="$(tfc workspaces create --name "$TFC_LANDING_WS" --project-id "$TFC_LANDING_PROJ" ${TFC_OPTS} \
           | jq -r '.id')"
fi

# ── Step 8: Adopt via import ───────────────────────────────────────

cd "$REPO_ROOT/infrastructure" || exit 1

export TF_ADDRESS="https://app.terraform.io"
export TF_CREDENTIALS="env"
export TF_HTTP_USERNAME="token"
export TF_HTTP_PASSWORD="${TF_TOKEN_APP_TERRAFORM_IO}"
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

# 8a. Folders
import_one "module.google-folder.google_folder.tree[\"ef-root\"]" "$GCP_ROOT_FOLDER_ID"
import_one "module.google-folder.google_folder.tree[\"ef-mgt\"]" "$GCP_MGT_FOLDER_ID"

# 8b. Landing project
GCP_PROJECT_NUM="$(gcloud projects describe "$GCP_DEFAULT_PROJECT" --format='value(projectNumber)' 2>/dev/null | head -n1)"
[[ -n "$GCP_PROJECT_NUM" ]] || die "project $GCP_DEFAULT_PROJECT not found"
import_one "module.google-project[\"$GCP_DEFAULT_PROJECT\"].google_project.this" "$GCP_PROJECT_NUM"

# 8c. Service account
import_one "module.google-service-account[\"sa-mgt-tfc\"].google_service_account.this" "$SA_EMAIL"

# 8d. TFC project
TFC_PID="$(tfc projects list ${TFC_OPTS} | jq -r 'select(.name=="ef-mgt") | .id' | head -n1)"
[[ -n "$TFC_PID" ]] || die "TFC project ef-mgt not found"
import_one "module.tfe-project[\"ef-mgt\"].tfe_project.this" "prj-$TFC_PID"

# 8e. Workspace + settings
TFC_WSID="$(tfc workspaces list ${TFC_OPTS} --project-id "$TFC_LANDING_PROJ" \
         | jq -r "select(.name==\"$TFC_LANDING_WS\") | .id" | head -n1)"
[[ -n "$TFC_WSID" ]] || die "workspace $TFC_LANDING_WS not found"
import_one "module.tfe-workspace[\"$TFC_LANDING_WS\"].tfe_workspace.this" "$TFC_WSID"
import_one "module.tfe-workspace[\"$TFC_LANDING_WS\"].tfe_workspace_settings.this" "$TFC_WSID"

# 8f. GitHub repo
import_one "module.github-repository[\"$GCP_DEFAULT_PROJECT\"].github_repository.this" "$GCP_DEFAULT_PROJECT"


log "import complete — now prove the loop: terraform plan must show no diff"

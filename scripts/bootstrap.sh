#!/usr/bin/env bash
set -euo pipefail

# ── Bootstrap: EF platform bring-up ────────────────────────────────
# 1) Setup Google Cloud — create seed resources TF cannot make itself
# 2) Setup Terraform Cloud — create seed TFC resources
# 3) Render imports from template — collect IDs, pass to mustache renderer
# 4) Deploy — single terraform apply to import + deploy everything
# ──────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_DIR="$REPO_ROOT/environments/mgt"
INFRA_DIR="$REPO_ROOT/infrastructure"

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

for t in gcloud terraform jq curl git tfc python3; do
  command -v "$t" >/dev/null || die "$t not found on PATH"
done

export TF_TOKEN_APP_TERRAFORM_IO

# ── Step 1: Setup Google Cloud ─────────────────────────────────────

log "=== Step 1: Setup Google Cloud ==="

GCP_ORG="$(gcloud organizations list --filter="display_name=${GCP_DOMAIN}" --format='value(name)' | head -n1)"
[[ -n "$GCP_ORG" ]] || die "organisation not resolved — set EF_ORG_ID or EF_GCP_DOMAIN"

if gcloud projects describe "$GCP_DEFAULT_PROJECT" >/dev/null 2>&1; then
  log "project $GCP_DEFAULT_PROJECT already exists"
else
  log "creating project $GCP_DEFAULT_PROJECT under $GCP_ORG"
  gcloud projects create "$GCP_DEFAULT_PROJECT" \
    --billing-account="$GCP_BILLING_ACCOUNT" \
    --set-as-default
fi

log "enabling APIs on $GCP_DEFAULT_PROJECT"
gcloud services enable \
  iam.googleapis.com serviceusage.googleapis.com cloudbilling.googleapis.com \
  dns.googleapis.com compute.googleapis.com \
  --project="$GCP_DEFAULT_PROJECT"

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

# ── Step 2: Setup Terraform Cloud ──────────────────────────────────

log "=== Step 2: Setup Terraform Cloud ==="

TFC_OPTS="--address https://${TFC_HOSTNAME} --org ${TFC_ORG} --output-format json"

TFC_ORG_ID="$(tfc organizations get --name "$TFC_ORG" ${TFC_OPTS} | jq -r '.id')"

TFC_LANDING_PROJ="$(tfc projects list ${TFC_OPTS} | jq -r 'select(.name=="ef-mgt") | .id' | head -n1)"
if [[ -z "$TFC_LANDING_PROJ" ]]; then
  log "creating TFC project ef-mgt"
  TFC_LANDING_PROJ="$(tfc projects create --name ef-mgt ${TFC_OPTS} | jq -r '.id')"
else
  log "TFC project ef-mgt already exists ($TFC_LANDING_PROJ)"
fi

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

# ── Step 3: Render imports from template ───────────────────────────

log "=== Step 3: Render imports from template ==="

cd "$INFRA_DIR" || exit 1

export TF_ADDRESS="https://app.terraform.io"
export TF_CREDENTIALS="env"
export TF_HTTP_USERNAME="token"
export TF_HTTP_PASSWORD="${TF_TOKEN_APP_TERRAFORM_IO}"
export TF_WORKSPACE="${EF_TFC_WORKSPACE:-ef-mgt-devops}"
export TF_VAR_environment="mgt"

log "init against remote workspace $TF_WORKSPACE"
terraform init -backend-config="organization=$TFC_ORG"

collect_import() {
  local addr="$1" id="$2"
  [[ -n "$id" && "$id" != "folders/" ]] || { warn "skipping $addr — ID empty"; return 0; }
  log "import $addr <- $id"
}

# Collect resource IDs as JSON array for template rendering
IMPORTS_JSON=$(jq -n -c '[
  {
    "address": "module.google-project[\"'"$GCP_DEFAULT_PROJECT"'\"].google_project.this",
    "id": "'"$(gcloud projects describe "$GCP_DEFAULT_PROJECT" --format='value(projectNumber)' 2>/dev/null | head -n1)"'"
  },
  {
    "address": "module.google-service-account[\"sa-mgt-tfc\"].google_service_account.this",
    "id": "'"$SA_EMAIL"'"
  },
  {
    "address": "module.tfe-project[\"ef-mgt\"].tfe_project.this",
    "id": "'prj-$(tfc projects list ${TFC_OPTS} | jq -r 'select(.name=="ef-mgt") | .id' | head -n1)'"
  },
  {
    "address": "module.tfe-workspace[\"'"$TFC_LANDING_WS"'\"].tfe_workspace.this",
    "id": "'"$TFC_WSID"'"
  },
  {
    "address": "module.tfe-workspace[\"'"$TFC_LANDING_WS"'\"].tfe_workspace_settings.this",
    "id": "'"$TFC_WSID"'"
  },
  {
    "address": "module.github-repository[\"'"$GCP_DEFAULT_PROJECT"'\"].github_repository.this",
    "id": "'"$GCP_DEFAULT_PROJECT"'"
  }
]')

collect_import "module.google-project[\"$GCP_DEFAULT_PROJECT\"].google_project.this" \
  "$(echo $IMPORTS_JSON | jq -r '.[0].id')"
collect_import "module.google-service-account[\"sa-mgt-tfc\"].google_service_account.this" \
  "$(echo $IMPORTS_JSON | jq -r '.[1].id')"
collect_import "module.tfe-project[\"ef-mgt\"].tfe_project.this" \
  "$(echo $IMPORTS_JSON | jq -r '.[2].id')"
collect_import "module.tfe-workspace[\"$TFC_LANDING_WS\"].tfe_workspace.this" \
  "$(echo $IMPORTS_JSON | jq -r '.[3].id')"
collect_import "module.tfe-workspace[\"$TFC_LANDING_WS\"].tfe_workspace_settings.this" \
  "$(echo $IMPORTS_JSON | jq -r '.[4].id')"
collect_import "module.github-repository[\"$GCP_DEFAULT_PROJECT\"].github_repository.this" \
  "$(echo $IMPORTS_JSON | jq -r '.[5].id')"

log "rendering imports.tf from template"

TMPJSON=$(mktemp)
trap 'rm -f "$TMPJSON"' EXIT

GCP_PROJ_NUM="$(gcloud projects describe "$GCP_DEFAULT_PROJECT" --format='value(projectNumber)' 2>/dev/null | head -n1)"
[[ -n "$GCP_PROJ_NUM" ]] || die "project number not found for $GCP_DEFAULT_PROJECT"
TFC_PROJ_ID="$(tfc projects list ${TFC_OPTS} | jq -r 'select(.name=="ef-mgt") | .id' | head -n1)"
[[ -n "$TFC_PROJ_ID" ]] || die "TFC project ef-mgt not found"

jq -n \
  --arg gcp_dp "$GCP_DEFAULT_PROJECT" \
  --arg gcp_pn "$GCP_PROJ_NUM" \
  --arg sa_email "$SA_EMAIL" \
  --arg tfc_env "mgt" \
  --arg tfc_pid "$TFC_PROJ_ID" \
  --arg tfc_ws "ef-mgt-devops" \
  --arg tfc_wsid "$TFC_WSID" \
  '{
    gcp_default_project: $gcp_dp,
    gcp_project_number: $gcp_pn,
    sa_email: $sa_email,
    tfc_env_name: $tfc_env,
    tfc_project_id: $tfc_pid,
    tfc_ws_name: $tfc_ws,
    tfc_workspace_id: $tfc_wsid
  }' > "$TMPJSON"

python3 -c "
import json, pystache
with open('${INFRA_DIR}/imports.tf.tmpl') as f:
    tmpl = f.read()
with open('$TMPJSON') as f:
    ctx = json.load(f)
print(pystache.render(tmpl, ctx))
" > imports.tf

log "imports.tf rendered — $(wc -l < imports.tf) lines"

# ── Step 4: Deploy ─────────────────────────────────────────────────

log "=== Step 4: Deploy ==="
log "Running terraform apply to import existing + deploy non-existing resources"
terraform apply -auto-approve

log "deploy complete"

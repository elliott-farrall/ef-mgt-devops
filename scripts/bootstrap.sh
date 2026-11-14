#!/usr/bin/env bash
set -euo pipefail

# ── Bootstrap: EF platform bring-up ────────────────────────────────
# 1) Setup Google Cloud — create seed resources TF cannot make itself
# 2) Setup Terraform Cloud — create seed TFC resources
# 3) Render imports from template — pass IDs collected in steps 1&2
# 4) Deploy — single terraform apply to import + deploy everything
# ──────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_DIR="$REPO_ROOT/environments/mgt"
INFRA_DIR="$REPO_ROOT/infrastructure"

die()   { printf '\033[1;31mfatal: %s\n' "$*" >&2; exit 1; }

# Tree-aligned loggers — fixed-width prefixes for perfect vertical alignment
h()     { printf '%s\n' "$*"; }          # header, no indent
t()     { printf '│→ %s\n' "$*"; }                              # substep action
r()     { printf '│  └── %s\n' "$*"; }                          # result (under action text)

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

for t in gcloud terraform jq curl git tfc envsubst; do
  command -v "$t" >/dev/null || die "$t not found on PATH"
done

export TF_TOKEN_APP_TERRAFORM_IO

# ══════════════════════════════════════════════════════════════════
# Step 1: Setup Google Cloud
# ══════════════════════════════════════════════════════════════════

h "1) Setup Google Cloud"

t "1.1 Resolving organisation ${GCP_DOMAIN}"
GCP_ORG="$(gcloud organizations list --filter="display_name=${GCP_DOMAIN}" --format='value(name)' | head -n1)"
[[ -n "$GCP_ORG" ]] || die "organisation not resolved — set EF_ORG_ID or EF_GCP_DOMAIN"
r "Resolved GCP org: $GCP_ORG"

t "1.2 Creating project $GCP_DEFAULT_PROJECT"
if gcloud projects describe "$GCP_DEFAULT_PROJECT" >/dev/null 2>&1; then
  r "Project already exists"
else
  gcloud projects create "$GCP_DEFAULT_PROJECT" \
    --folder="$GCP_ORG" \
    --billing-account="$GCP_BILLING_ACCOUNT" \
    --set-as-default
  r "Created project"
fi
GCP_PROJ_NUM="$(gcloud projects describe "$GCP_DEFAULT_PROJECT" --format='value(projectNumber)' 2>/dev/null | head -n1)"
[[ -n "$GCP_PROJ_NUM" ]] || die "project number not found for $GCP_DEFAULT_PROJECT"
r "Project number: $GCP_PROJ_NUM"

t "1.3 Enabling required APIs on $GCP_DEFAULT_PROJECT"
gcloud services enable \
  iam.googleapis.com serviceusage.googleapis.com cloudbilling.googleapis.com \
  dns.googleapis.com compute.googleapis.com \
  --project="$GCP_DEFAULT_PROJECT"
r "APIs enabled"

t "1.4 Creating service account sa-mgt-tfc"
SA_EMAIL="sa-mgt-tfc@$GCP_DEFAULT_PROJECT.iam.gserviceaccount.com"
if gcloud iam service-accounts list --project="$GCP_DEFAULT_PROJECT" --format="value(email)" \
   | grep -q "sa-mgt-tfc@"; then
  r "sa-mgt-tfc already exists"
else
  gcloud iam service-accounts create "sa-mgt-tfc" \
    --display-name="Management plane" \
    --project="$GCP_DEFAULT_PROJECT"
  r "Created sa-mgt-tfc"
fi

# ══════════════════════════════════════════════════════════════════
# Step 2: Setup Terraform Cloud
# ══════════════════════════════════════════════════════════════════

h "2) Setup Terraform Cloud"

TFC_OPTS="--address https://${TFC_HOSTNAME} --org ${TFC_ORG} --output-format json"

t "2.1 Resolving TFC organisation ${TFC_ORG}"
TFC_ORG_ID="$(tfc organizations get --name "$TFC_ORG" ${TFC_OPTS} | jq -r '.id')"
r "TFC org ID: $TFC_ORG_ID"

t "2.2 Creating TFC project ef-mgt"
TFC_LANDING_PROJ="$(tfc projects list ${TFC_OPTS} | jq -r 'select(.name=="ef-mgt") | .id' | head -n1)"
if [[ -z "$TFC_LANDING_PROJ" ]]; then
  TFC_LANDING_PROJ="$(tfc projects create --name ef-mgt ${TFC_OPTS} | jq -r '.id')"
  r "Created TFC project ef-mgt ($TFC_LANDING_PROJ)"
else
  r "TFC project ef-mgt already exists ($TFC_LANDING_PROJ)"
fi
TFC_PROJ_ID="$(tfc projects list ${TFC_OPTS} | jq -r 'select(.name=="ef-mgt") | .id' | head -n1)"
[[ -n "$TFC_PROJ_ID" ]] || die "TFC project ef-mgt not found"
r "TFC project ID: $TFC_PROJ_ID"

t "2.3 Creating workspace ef-mgt-devops"
TFC_LANDING_WS="ef-mgt-devops"
TFC_WSID="$(tfc workspaces list ${TFC_OPTS} --project-id "$TFC_LANDING_PROJ" \
         | jq -r "select(.name==\"$TFC_LANDING_WS\") | .id" | head -n1)"
if [[ -n "$TFC_WSID" ]]; then
  r "Workspace already exists ($TFC_WSID)"
else
  TFC_WSID="$(tfc workspaces create --name "$TFC_LANDING_WS" --project-id "$TFC_LANDING_PROJ" ${TFC_OPTS} \
           | jq -r '.id')"
  r "Created workspace ($TFC_WSID)"
fi

# ══════════════════════════════════════════════════════════════════
# Step 3: Render imports from template
# ══════════════════════════════════════════════════════════════════

h "3) Render imports from template"

cd "$INFRA_DIR" || exit 1

export TF_ADDRESS="https://app.terraform.io"
export TF_CREDENTIALS="env"
export TF_HTTP_USERNAME="token"
export TF_HTTP_PASSWORD="${TF_TOKEN_APP_TERRAFORM_IO}"
export TF_WORKSPACE="${EF_TFC_WORKSPACE:-ef-mgt-devops}"
export TF_VAR_environment="mgt"

t "3.1 Initialising terraform against workspace $TF_WORKSPACE"
terraform init -backend-config="organization=$TFC_ORG"
r "Initialised"

t "3.2 Passing resource IDs to template"
export GCP_DEFAULT_PROJECT
export GCP_PROJ_NUM
export SA_EMAIL
export TFC_ENV_NAME=mgt
export TFC_PROJ_ID
export TFC_WS_NAME=ef-mgt-devops
export TFC_WSID
r "Exported: GCP_DEFAULT_PROJECT, GCP_PROJ_NUM, SA_EMAIL, TFC_PROJ_ID, TFC_WSID"

t "3.3 Rendering imports.tf from template"
envsubst < "$INFRA_DIR/imports.tf.tmpl" > imports.tf
r "Rendered imports.tf — $(wc -l < imports.tf) lines"

# ══════════════════════════════════════════════════════════════════
# Step 4: Deploy
# ══════════════════════════════════════════════════════════════════

h "4) Deploy"
t "Running terraform apply to import existing + deploy non-existing resources"
terraform apply -auto-approve
r "deploy complete"

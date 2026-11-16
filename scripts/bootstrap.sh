#!/usr/bin/env bash
set -euo pipefail

# ── Bootstrap: EF platform bring-up ────────────────────────────────
# 1) Setup Google Cloud — create seed resources TF cannot make itself
# 2) Setup Terraform Cloud — create seed TFC resources  
# 3) Render imports from template — pass IDs collected in steps 1&2
# 4) Deploy — single terraform apply to import + deploy everything
# ──────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_DIR="${REPO_ROOT}/environments/mgt"
INFRA_DIR="${REPO_ROOT}/infrastructure"

die()   { printf '\033[1;31mfatal: %s\n' "$*" >&2; exit 1; }

# Tree-aligned loggers — fixed-width prefixes for perfect vertical alignment
h()     { printf '%s\n' "$*"; }          # header, no indent
t()     { printf '├── %s\n' "$*"; }      # substep action
r()     { printf '│   └── %s\n' "$*"; }  # result (aligned under action)

# ══════════════════════════════════════════════════════════════════
# Dependencies
# ══════════════════════════════════════════════════════════════════

h "Dependencies"

for t in gcloud terraform jq git tfccli envsubst yq; do
  command -v "${t}" >/dev/null || die "${t} not found on PATH"
done

# ══════════════════════════════════════════════════════════════════
# Config — load org/project configs
# ══════════════════════════════════════════════════════════════════

h "Config"

GCP_DOMAIN=$(yq '.organisation.gcp.domain' "${ENV_DIR}/organisation.yaml")
GCP_BILLING_NAME=$(yq '.organisation.gcp.billing' "${ENV_DIR}/organisation.yaml")

# Load all project configs from env dir (envs + libs YAML files)
PROJECT_CONFIGS=$(mktemp)
for f in $(find "${ENV_DIR}" -name "*.yaml" ! -path "*organisation.yaml" | sort); do
  echo "" >> "${PROJECT_CONFIGS}"
  yq '.' "${f}" >> "${PROJECT_CONFIGS}"
done

# Derive default devops project info from mgt environment YAML
MGT_ENV_YAML="${ENV_DIR}/environments.yaml"
if ! grep -q '^  - name: mgt$' "${MGT_ENV_YAML}" || \
   ! grep -A50 '^  - name: mgt$' "${MGT_ENV_YAML}" | grep -q 'name: devops'; then
  die "mgt/devops project configuration missing from ${MGT_ENV_YAML}"
fi

DEVOPS_SERVICES=$(grep -A200 '^  - name: mgt$' "${MGT_ENV_YAML}" | grep -A50 'projects:' | grep 'services:' | tail -1 | tr -d ' :')

TFC_ORG=$(yq '.organisation.tfe.organisation' "${ENV_DIR}/organisation.yaml")
TFC_HOSTNAME=$(yq '.organisation.tfe.hostname' "${ENV_DIR}/organisation.yaml")
GH_OWNER=$(yq '.organisation.gh.owner' "${ENV_DIR}/organisation.yaml")

[[ -n "${GCP_DOMAIN}" ]] || die "gcp domain not found in ${ENV_DIR}/organisation.yaml"
[[ -n "${GCP_BILLING_NAME}" ]] || die "billing account name not found in ${ENV_DIR}/organisation.yaml"
GCP_BILLING_ACCOUNT="$(gcloud billing accounts list --filter="displayName=${GCP_BILLING_NAME}" --format='value(name)' 2>/dev/null | head -n1)"
[[ -n "${GCP_BILLING_ACCOUNT}" ]] || die "billing account ${GCP_BILLING_NAME} not found or not accessible"
GCP_BILLING_ACCOUNT="${GCP_BILLING_ACCOUNT#billingAccounts/}"
r "Resolved billing account: ${GCP_BILLING_NAME} (${GCP_BILLING_ACCOUNT})"
[[ -n "${DEVOPS_SERVICES}" ]] || die "devops services missing from mgt/environments.yaml"
[[ -n "${TFC_ORG}" ]] || die "TFC organisation not found in ${ENV_DIR}/organisation.yaml"
[[ -n "${TFC_HOSTNAME}" ]] || die "TFC hostname not found in ${ENV_DIR}/organisation.yaml"
[[ -n "${GH_OWNER}" ]] || die "GitHub owner not found in ${ENV_DIR}/organisation.yaml"

# Derived identifiers — built once from config, referenced everywhere
SA_NAME="sa-mgt-tfc"
SA_EMAIL="${SA_NAME}@ef-mgt-devops.iam.gserviceaccount.com"

# ══════════════════════════════════════════════════════════════════
# Phase 1: Setup Google Cloud
# ══════════════════════════════════════════════════════════════════

h "Phase 1: Google Cloud"

t "1.1. Verify gcloud authentication"
if ! gcloud auth list --filter=status:ACTIVE --format='value(account)' >/dev/null 2>&1; then
  r "Not authenticated — run: gcloud init"
  die "Abort: authenticate with gcloud first"
fi
CURRENT_GCP_ACCT="$(gcloud auth list --filter=status:ACTIVE --format='value(account)')"
r "Authenticated as ${CURRENT_GCP_ACCT}"

t "1.2. Resolving GCP organisation ${GCP_DOMAIN}"
GCP_ORG_ID="$(gcloud organizations list \
  --filter="display_name=${GCP_DOMAIN}" \
  --format='value(name)' 2>/dev/null | head -n1)"
if [[ -z "${GCP_ORG_ID}" ]]; then
  r "Organisation '${GCP_DOMAIN}' not accessible"
  die "Abort: account '${CURRENT_GCP_ACCT}' lacks access to '${GCP_DOMAIN}'"
fi
GCP_ORG="folders/${GCP_ORG_ID#organizations/}"
r "Resolved: ${GCP_ORG_ID} (${GCP_ORG})"

t "1.3. Creating project ef-mgt-devops"
if gcloud projects describe "ef-mgt-devops" >/dev/null 2>&1; then
  r "Project already exists"
else
  gcloud projects create "ef-mgt-devops" \
    --folder="${GCP_ORG_ID#/folders/}" \
    --billing-account="${GCP_BILLING_ACCOUNT}" \
    --set-as-default
  r "Created project"
fi
GCP_PROJ_NUM="$(gcloud projects describe "ef-mgt-devops" --format='value(projectNumber)' 2>/dev/null | head -n1)"
[[ -n "${GCP_PROJ_NUM}" ]] || die "project number not found for ef-mgt-devops"
r "Project number: ${GCP_PROJ_NUM}"

t "1.4. Enabling required APIs on ef-mgt-devops"
if [[ -z "${DEVOPS_SERVICES}" ]]; then
  r "No services configured (handled by Terraform)"
else
  IFS=$'\n' SERVICES_ARR=(${DEVOPS_SERVICES//[$'\n']/ })
  unset IFS
  for svc in "${SERVICES_ARR[@]}"; do
    gcloud services enable "${svc}" --project="ef-mgt-devops"
    r "Enabled API: ${svc}"
  done
fi
r "APIs ready"

t "1.5. Creating service account sa-mgt-tfc"
if gcloud iam service-accounts list --project="ef-mgt-devops" --format="value(email)" \
   | grep -q "${SA_NAME}@"; then
  r "sa-mgt-tfc already exists"
else
  gcloud iam service-accounts create "${SA_NAME}" \
    --display-name="Management plane" \
    --project="ef-mgt-devops"
  r "Created sa-mgt-tfc"
fi

# ══════════════════════════════════════════════════════════════════
# Phase 2: Setup Terraform Cloud
# ══════════════════════════════════════════════════════════════════

h "Phase 2: Terraform Cloud"

TFC_OPTS="--address https://${TFC_HOSTNAME} --org ${TFC_ORG} --output-format json"

t "2.1. Verify Terraform Cloud token"
if [[ -z "${TF_TOKEN_APP_TERRAFORM_IO:-}" ]]; then
  r "Token not set — set TF_TOKEN_APP_TERRAFORM_IO environment variable"
  die "Abort: set TF_TOKEN_APP_TERRAFORM_IO first"
fi
# Single call: validates access and captures org ID in one pass
TFC_ORG_ID="$(tfccli organizations get --name "${TFC_ORG}" ${TFC_OPTS} | jq -r '.data.id' 2>/dev/null)"
if [[ -z "${TFC_ORG_ID}" || "${TFC_ORG_ID}" == "null" ]]; then
  r "Organisation '${TFC_ORG}' inaccessible"
  die "Abort: token lacks access to TFC organisation '${TFC_ORG}'"
fi
r "Authenticated, organisation ${TFC_ORG} accessible"

t "2.2. Creating TFC project ef-mgt"
TFC_PROJECT_ID="$(tfccli projects list ${TFC_OPTS} | jq -r 'select(.name=="ef-mgt") | .id' | head -n1)"
if [[ -z "${TFC_PROJECT_ID}" || "${TFC_PROJECT_ID}" == "null" ]]; then
  TFC_PROJECT_ID="$(tfccli projects create --name ef-mgt ${TFC_OPTS} | jq -r '.id')"
  r "Created TFC project ef-mgt (${TFC_PROJECT_ID})"
else
  r "TFC project ef-mgt already exists (${TFC_PROJECT_ID})"
fi
r "Project ID: ${TFC_PROJECT_ID}"

t "2.3. Creating workspace ef-mgt-devops"
TFC_WORKSPACE_ID="$(tfccli workspaces list ${TFC_OPTS} --project-id "${TFC_PROJECT_ID}" \
         | jq -r "select(.name==\"ef-mgt-devops\") | .id" | head -n1)"
if [[ -n "${TFC_WORKSPACE_ID}" ]]; then
  r "Workspace already exists (${TFC_WORKSPACE_ID})"
else
  TFC_WORKSPACE_ID="$(tfccli workspaces create --name "ef-mgt-devops" --project-id "${TFC_PROJECT_ID}" ${TFC_OPTS} \
           | jq -r '.id')"
  r "Created workspace (${TFC_WORKSPACE_ID})"
fi

# ══════════════════════════════════════════════════════════════════
# Phase 3: Render imports from template
# ══════════════════════════════════════════════════════════════════

h "Phase 3: Render imports"

t "3.1. Rendering imports.tf from template"
envsubst < "${INFRA_DIR}/imports.tf.tmpl" > "${INFRA_DIR}/imports.tf"
r "Rendered imports.tf — $(wc -l < "${INFRA_DIR}/imports.tf") lines"

# ══════════════════════════════════════════════════════════════════
# Phase 4: Deploy
# ══════════════════════════════════════════════════════════════════

h "Phase 4: Deploy"

t "4.1. Initialising Terraform against workspace ef-mgt-devops"
export TF_ADDRESS="https://${TFC_HOSTNAME}"
export TF_CREDENTIALS="env"
export TF_HTTP_USERNAME="token"
export TF_HTTP_PASSWORD="${TF_TOKEN_APP_TERRAFORM_IO}"
export TF_WORKSPACE="ef-mgt-devops"
terraform -chdir="${INFRA_DIR}" init -backend-config="organization=${TFC_ORG}"
r "Initialised"

t "Running Terraform apply to import existing + deploy non-existing resources"
terraform -chdir="${INFRA_DIR}" apply -auto-approve
r "Deploy complete"

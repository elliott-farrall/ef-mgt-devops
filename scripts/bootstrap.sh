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

for t in gcloud terraform jq git tfc envsubst yq; do
  command -v "${t}" >/dev/null || die "${t} not found on PATH"
done

# ══════════════════════════════════════════════════════════════════
# Config
# ══════════════════════════════════════════════════════════════════

h "Config"

GCP_DOMAIN=$(yq '.organisation.gcp.domain' "${ENV_DIR}/organisation.yaml")
GCP_BILLING_ACCOUNT=$(yq '.billing.billing_account_id' "${ENV_DIR}/billing.yaml")

GCP_PROJECT_ENV=$(yq '.environments[] | select(.projects[]?.default == true) | .name' "${ENV_DIR}/environments.yaml")
GCP_PROJECT_SUFFIX=$(yq '.environments[] | select(.projects[]?.default == true) | .projects[] | select(.default == true) | .name' "${ENV_DIR}/environments.yaml")
GCP_PROJECT_NAME="ef-${GCP_PROJECT_ENV}-${GCP_PROJECT_SUFFIX}"

TFC_ORG=$(yq '.organisation.tfe.organisation' "${ENV_DIR}/organisation.yaml")
TFC_HOSTNAME=$(yq '.organisation.tfe.hostname' "${ENV_DIR}/organisation.yaml")

[[ -n "${GCP_DOMAIN}" ]] || die "gcp domain not found in ${ENV_DIR}/organisation.yaml"
[[ -n "${GCP_BILLING_ACCOUNT}" ]] || die "GCP billing account id not found in ${ENV_DIR}/billing.yaml"
[[ -n "${GCP_PROJECT_ENV}" && -n "${GCP_PROJECT_SUFFIX}" ]] || \
  die "environment config missing from ${ENV_DIR}/environments.yaml"
[[ -n "${TFC_ORG}" ]] || die "TFC organisation not found in ${ENV_DIR}/organisation.yaml"
[[ -n "${TFC_HOSTNAME}" ]] || die "TFC hostname not found in ${ENV_DIR}/organisation.yaml"

# Derived identifiers — built once from config, referenced everywhere
SA_NAME="sa-mgt-tfc"
SA_EMAIL="${SA_NAME}@${GCP_PROJECT_NAME}.iam.gserviceaccount.com"
TFC_LANDING_WS="${GCP_PROJECT_NAME}"

# ══════════════════════════════════════════════════════════════════
# Step 1: Setup Google Cloud
# ══════════════════════════════════════════════════════════════════

h "1. Setup Google Cloud"

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

t "1.3. Creating project ${GCP_PROJECT_NAME}"
if gcloud projects describe "${GCP_PROJECT_NAME}" >/dev/null 2>&1; then
  r "Project already exists"
else
  gcloud projects create "${GCP_PROJECT_NAME}" \
    --folder="${GCP_ORG_ID#/folders/}" \
    --billing-account="${GCP_BILLING_ACCOUNT}" \
    --set-as-default
  r "Created project"
fi
GCP_PROJ_NUM="$(gcloud projects describe "${GCP_PROJECT_NAME}" --format='value(projectNumber)' 2>/dev/null | head -n1)"
[[ -n "${GCP_PROJ_NUM}" ]] || die "project number not found for ${GCP_PROJECT_NAME}"
r "Project number: ${GCP_PROJ_NUM}"

# Read services list from config for this project
GCP_PROJECT_SERVICES=($(yq '.environments[] | select(.name=="'"${GCP_PROJECT_ENV}"'").projects[] | select(.name=="'"${GCP_PROJECT_SUFFIX}"'").services[]?' "${ENV_DIR}/environments.yaml"))

# Enable required APIs (bootstrap minimum — full list handled by Terraform)
t "1.4. Enabling required APIs on ${GCP_PROJECT_NAME}"
if [[ ${#GCP_PROJECT_SERVICES[@]} -eq 0 ]]; then
  r "No services configured (handled by Terraform)"
else
  for svc in "${GCP_PROJECT_SERVICES[@]}"; do
    gcloud services enable "${svc}" --project="${GCP_PROJECT_NAME}"
    r "Enabled API: ${svc}"
  done
fi
r "APIs ready"

t "1.5. Creating service account sa-mgt-tfc"
if gcloud iam service-accounts list --project="${GCP_PROJECT_NAME}" --format="value(email)" \
   | grep -q "${SA_NAME}@"; then
  r "sa-mgt-tfc already exists"
else
  gcloud iam service-accounts create "${SA_NAME}" \
    --display-name="Management plane" \
    --project="${GCP_PROJECT_NAME}"
  r "Created sa-mgt-tfc"
fi

# ══════════════════════════════════════════════════════════════════
# Step 2: Setup Terraform Cloud
# ══════════════════════════════════════════════════════════════════

h "2. Setup Terraform Cloud"

TFC_OPTS="--address https://${TFC_HOSTNAME} --org ${TFC_ORG} --output-format json"

t "2.1. Verify Terraform Cloud token"
if [[ -z "${TF_TOKEN_APP_TERRAFORM_IO:-}" ]]; then
  r "Token not set — set TF_TOKEN_APP_TERRAFORM_IO environment variable"
  die "Abort: set TF_TOKEN_APP_TERRAFORM_IO first"
fi
# Single call: validates access and captures org ID in one pass
TFC_ORG_ID="$(tfc organizations get --name "${TFC_ORG}" ${TFC_OPTS} | jq -r '.data.id' 2>/dev/null)"
if [[ -z "${TFC_ORG_ID}" || "${TFC_ORG_ID}" == "null" ]]; then
  r "Organisation '${TFC_ORG}' inaccessible"
  die "Abort: token lacks access to TFC organisation '${TFC_ORG}'"
fi
r "Authenticated, organisation ${TFC_ORG} accessible"

t "2.2. Creating TFC project ef-mgt"
TFC_LANDING_PROJ="$(tfc projects list ${TFC_OPTS} | jq -r 'select(.name=="ef-mgt") | .id' | head -n1)"
if [[ -z "${TFC_LANDING_PROJ}" ]]; then
  TFC_LANDING_PROJ="$(tfc projects create --name ef-mgt ${TFC_OPTS} | jq -r '.id')"
  r "Created TFC project ef-mgt (${TFC_LANDING_PROJ})"
else
  r "TFC project ef-mgt already exists (${TFC_LANDING_PROJ})"
fi
TFC_PROJ_ID="$(tfc projects list ${TFC_OPTS} | jq -r 'select(.name=="ef-mgt") | .id' | head -n1)"
[[ -n "${TFC_PROJ_ID}" ]] || die "TFC project ef-mgt not found"
r "TFC project ID: ${TFC_PROJ_ID}"

t "2.3. Creating workspace ${TFC_LANDING_WS}"
TFC_WSID="$(tfc workspaces list ${TFC_OPTS} --project-id "${TFC_LANDING_PROJ}" \
         | jq -r "select(.name==\"${TFC_LANDING_WS}\") | .id" | head -n1)"
if [[ -n "${TFC_WSID}" ]]; then
  r "Workspace already exists (${TFC_WSID})"
else
  TFC_WSID="$(tfc workspaces create --name "${TFC_LANDING_WS}" --project-id "${TFC_LANDING_PROJ}" ${TFC_OPTS} \
           | jq -r '.id')"
  r "Created workspace (${TFC_WSID})"
fi

# ══════════════════════════════════════════════════════════════════
# Step 3: Render imports from template
# ══════════════════════════════════════════════════════════════════

h "3. Render imports from template"

t "3.1. Rendering imports.tf from template"
envsubst < "${INFRA_DIR}/imports.tf.tmpl" > "${INFRA_DIR}/imports.tf"
r "Rendered imports.tf — $(wc -l < "${INFRA_DIR}/imports.tf") lines"

# ══════════════════════════════════════════════════════════════════
# Step 4: Deploy
# ══════════════════════════════════════════════════════════════════

h "4. Deploy"

t "4.1. Initialising terraform against workspace ${TFC_LANDING_WS}"
export TF_ADDRESS="https://${TFC_HOSTNAME}"
export TF_CREDENTIALS="env"
export TF_HTTP_USERNAME="token"
export TF_HTTP_PASSWORD="${TF_TOKEN_APP_TERRAFORM_IO}"
export TF_WORKSPACE="${GCP_PROJECT_NAME}"
export TF_VAR_environment="${GCP_PROJECT_ENV}"
terraform -chdir="${INFRA_DIR}" init -backend-config="organization=${TFC_ORG}"
r "Initialised"

t "Running terraform apply to import existing + deploy non-existing resources"
terraform -chdir="${INFRA_DIR}" apply -auto-approve
r "deploy complete"

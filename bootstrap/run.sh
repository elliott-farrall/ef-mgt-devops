#!/usr/bin/env bash
set -euo pipefail

# ── Bootstrap: cloud landing zone bring-up ────────────────────────
# 1) Google Cloud   — seed: folder, project, APIs, mgt identity
# 2) Terraform Cloud — seed: project, workspace, credential variables
# 3) Imports        — render bootstrap.tf from the collected IDs
# 4) Deploy         — local-execution apply importing + creating everything
# ──────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_DIR="${REPO_ROOT}/environments/mgt"
INFRA_DIR="${REPO_ROOT}/infrastructure"
BOOTSTRAP_DIR="${REPO_ROOT}/bootstrap"

die()   { printf '\033[1;31mfatal: %s\n' "$*" >&2; exit 1; }
h()     { printf '%s\n' "$*"; }
t()     { printf '├── %s\n' "$*"; }
r()     { printf '│   └── %s\n' "$*"; }

# ══════════════════════════════════════════════════════════════════
# Dependencies
# ══════════════════════════════════════════════════════════════════

h "Dependencies"

for tool in gcloud terraform jq git tfccli envsubst yq; do
  command -v "${tool}" >/dev/null || die "${tool} not found on PATH"
done

# ══════════════════════════════════════════════════════════════════
# Config
# ══════════════════════════════════════════════════════════════════

h "Config"

GCP_DOMAIN=$(yq -r '.organisation.gcp.domain' "${ENV_DIR}/organisation.yaml")
GCP_BILLING_NAME=$(yq -r '.organisation.gcp.billing' "${ENV_DIR}/organisation.yaml")
TFC_ORG=$(yq -r '.organisation.tfe.organisation' "${ENV_DIR}/organisation.yaml")
TFC_HOSTNAME=$(yq -r '.organisation.tfe.hostname' "${ENV_DIR}/organisation.yaml")
GH_OWNER=$(yq -r '.organisation.gh.owner' "${ENV_DIR}/organisation.yaml")

MGT_ENV_YAML="${ENV_DIR}/environments.yaml"
if ! grep -q '^  - name: mgt$' "${MGT_ENV_YAML}" || \
   ! grep -A50 '^  - name: mgt$' "${MGT_ENV_YAML}" | grep -q 'name: devops'; then
  die "mgt/devops project configuration missing from ${MGT_ENV_YAML}"
fi
mapfile -t DEVOPS_SERVICES < <(yq -r '.environments[] | select(.name=="mgt") | .projects[] | select(.name=="devops") | .services[]' "${MGT_ENV_YAML}")
[[ ${#DEVOPS_SERVICES[@]} -gt 0 ]] || die "devops services missing from mgt/environments.yaml"

[[ -n "${GCP_DOMAIN}" ]] || die "gcp domain not found in ${ENV_DIR}/organisation.yaml"
[[ -n "${GCP_BILLING_NAME}" ]] || die "billing account name not found in ${ENV_DIR}/organisation.yaml"
[[ -n "${TFC_ORG}" ]] || die "TFC organisation not found in ${ENV_DIR}/organisation.yaml"
[[ -n "${TFC_HOSTNAME}" ]] || die "TFC hostname not found in ${ENV_DIR}/organisation.yaml"
[[ -n "${GH_OWNER}" ]] || die "GitHub owner not found in ${ENV_DIR}/organisation.yaml"

[[ -f ~/.terraform.d/credentials.tfrc.json ]] || die "run terraform login first (stores the Terraform Cloud token)"
command -v gh >/dev/null || die "gh not found on PATH"
gh auth status >/dev/null 2>&1 || die "run gh auth login first (GitHub CLI authentication)"
[[ -n "${CF_API_TOKEN:-}" ]] || die "set CF_API_TOKEN (a Cloudflare token with Zone.DNS Edit on ${GCP_DOMAIN})"

GCP_DEFAULT_PROJECT="ef-mgt-devops"
SA_NAME="sa-mgt-tfc"
SA_EMAIL="${SA_NAME}@${GCP_DEFAULT_PROJECT}.iam.gserviceaccount.com"

# ══════════════════════════════════════════════════════════════════
# Phase 1: Google Cloud — seed the resources Terraform cannot create
# ══════════════════════════════════════════════════════════════════

h "Phase 1: Google Cloud"

t "1.1. Verifying gcloud authentication"
if ! gcloud auth list --filter=status:ACTIVE --format='value(account)' >/dev/null 2>&1; then
  r "Not authenticated — run: gcloud init"
  die "Abort: authenticate with gcloud first"
fi
CURRENT_GCP_ACCT="$(gcloud auth list --filter=status:ACTIVE --format='value(account)')"
r "Authenticated as ${CURRENT_GCP_ACCT}"

t "1.1.1. Verifying application-default credentials for the local apply"
if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
  r "No application-default credentials"
  die "Abort: run gcloud auth application-default login first"
fi
r "Application-default credentials present"

t "1.2. Checking the GCP organisation ${GCP_DOMAIN}"
GCP_ORG_ID="$(gcloud organizations list \
  --filter="display_name=${GCP_DOMAIN}" \
  --format='value(name)' 2>/dev/null | head -n1)"
if [[ -z "${GCP_ORG_ID}" ]]; then
  r "Organisation '${GCP_DOMAIN}' not accessible"
  die "Abort: account '${CURRENT_GCP_ACCT}' lacks access to '${GCP_DOMAIN}'"
fi
r "Resolved: ${GCP_ORG_ID}"

t "1.3. Checking the environment folder ef-mgt"
FOLDER_NAME="$(gcloud resource-manager folders list \
  --organization="${GCP_ORG_ID#organizations/}" \
  --filter="displayName=ef-mgt" --format='value(name)' 2>/dev/null | head -n1)"
if [[ -z "${FOLDER_NAME}" ]]; then
  FOLDER_NAME="$(gcloud resource-manager folders create \
    --display-name="ef-mgt" \
    --organization="${GCP_ORG_ID#organizations/}" --format='value(name)')"
  r "Created folder ef-mgt"
else
  r "Folder ef-mgt already exists"
fi
FOLDER_ID="${FOLDER_NAME#folders/}"
r "Folder ef-mgt: ${FOLDER_NAME}"

t "1.4. Checking the project ${GCP_DEFAULT_PROJECT}"
if gcloud projects describe "${GCP_DEFAULT_PROJECT}" >/dev/null 2>&1; then
  r "Project already exists"
else
  gcloud projects create "${GCP_DEFAULT_PROJECT}" \
    --folder="${FOLDER_ID}" \
    --billing-account="${GCP_BILLING_ACCOUNT}" \
    --set-as-default
  r "Created project"
fi
GCP_PROJ_NUM="$(gcloud projects describe "${GCP_DEFAULT_PROJECT}" --format='value(projectNumber)' 2>/dev/null | head -n1)"
[[ -n "${GCP_PROJ_NUM}" ]] || die "project number not found for ${GCP_DEFAULT_PROJECT}"
r "Project number: ${GCP_PROJ_NUM}"

t "1.5. Enabling the required APIs"
gcloud services enable iam.googleapis.com serviceusage.googleapis.com cloudbilling.googleapis.com dns.googleapis.com compute.googleapis.com \
  --project="${GCP_DEFAULT_PROJECT}"
r "Enabled APIs: ${DEVOPS_SERVICES[*]}"

t "1.6. Creating the mgt identity ${SA_NAME}"
if gcloud iam service-accounts describe "${SA_EMAIL}" --project="${GCP_DEFAULT_PROJECT}" >/dev/null 2>&1; then
  r "Identity already exists"
else
  gcloud iam service-accounts create "${SA_NAME}" \
    --display-name="Management plane" \
    --project="${GCP_DEFAULT_PROJECT}"
  r "Created identity"
fi

# ══════════════════════════════════════════════════════════════════
# Phase 2: Terraform Cloud — seed the org, workspace, credentials
# ══════════════════════════════════════════════════════════════════

h "Phase 2: Terraform Cloud"

TFC_OPTS="--address https://${TFC_HOSTNAME} --org ${TFC_ORG} --output-format json"
TFC_API="https://${TFC_HOSTNAME}/api/v2"
TFC_TOKEN="$(jq -r '.credentials["app.terraform.io"].token' ~/.terraform.d/credentials.tfrc.json)"
[[ -n "${TFC_TOKEN}" && "${TFC_TOKEN}" != "null" ]] || die "no Terraform Cloud token in ~/.terraform.d/credentials.tfrc.json — run terraform login"
TFC_AUTH=( -H "Authorization: Bearer ${TFC_TOKEN}" -H "Content-Type: application/vnd.api+json" )

t "2.1. Checking the Terraform Cloud token"
TFC_ORG_ID="$(tfccli organizations get --name "${TFC_ORG}" ${TFC_OPTS} | jq -r '.data.id' 2>/dev/null)"
if [[ -z "${TFC_ORG_ID}" || "${TFC_ORG_ID}" == "null" ]]; then
  r "Organisation '${TFC_ORG}' inaccessible"
  die "Abort: token lacks access to TFC organisation '${TFC_ORG}'"
fi
r "Authenticated, organisation ${TFC_ORG} accessible"

t "2.2. Checking the GitHub App installation ${GH_OWNER}"
GITHUB_INSTALLATION_ID="$(curl -s "${TFC_AUTH[@]}" "${TFC_API}/github-app/installations" \
  | jq -r ".data[] | select(.attributes.name==\"${GH_OWNER}\") | .id" | head -n1)"
if [[ -z "${GITHUB_INSTALLATION_ID}" ]]; then
  r "No GitHub App installation named '${GH_OWNER}' connected to the TFC organisation"
  die "Abort: install the Terraform Cloud GitHub App on the GitHub account '${GH_OWNER}', then rerun"
fi
r "GitHub App installation '${GH_OWNER}' connected"

t "2.3. Checking the TFC project ef-mgt"
TFC_PROJECT_ID="$(tfccli projects list ${TFC_OPTS} | jq -r 'select(.name=="ef-mgt") | .id' | head -n1)"
if [[ -z "${TFC_PROJECT_ID}" || "${TFC_PROJECT_ID}" == "null" ]]; then
  TFC_PROJECT_ID="$(tfccli projects create --name ef-mgt ${TFC_OPTS} | jq -r '.id')"
  r "Created TFC project ef-mgt (${TFC_PROJECT_ID})"
else
  r "TFC project ef-mgt already exists (${TFC_PROJECT_ID})"
fi

t "2.4. Checking the workspace ${GCP_DEFAULT_PROJECT}"
TFC_WORKSPACE_ID="$(tfccli workspaces list ${TFC_OPTS} --project-id "${TFC_PROJECT_ID}" \
         | jq -r "select(.name==\"${GCP_DEFAULT_PROJECT}\") | .id" | head -n1)"
if [[ -n "${TFC_WORKSPACE_ID}" ]]; then
  r "Workspace already exists (${TFC_WORKSPACE_ID})"
else
  TFC_WORKSPACE_ID="$(tfccli workspaces create --name "${GCP_DEFAULT_PROJECT}" --project-id "${TFC_PROJECT_ID}" ${TFC_OPTS} \
           | jq -r '.id')"
  r "Created workspace (${TFC_WORKSPACE_ID})"
fi

t "2.5. Setting workspace execution to local for the first apply"
curl -s -X POST "${TFC_AUTH[@]}" "${TFC_API}/workspaces/${TFC_WORKSPACE_ID}/settings" \
  -d "$(jq -n '{data: {type: "workspace-settings", attributes: {execution_mode: "local"}}}')" >/dev/null
r "Workspace runs locally for the first apply; Terraform switches it to remote"

t "2.6. Checking the organisation-wide token set platform-tokens"
VARSET_ID="$(curl -s "${TFC_AUTH[@]}" "${TFC_API}/organizations/${TFC_ORG}/varsets" \
  | jq -r '.data[] | select(.attributes.name=="platform-tokens") | .id' | head -n1)"
if [[ -z "${VARSET_ID}" ]]; then
  VARSET_ID="$(curl -s -X POST "${TFC_AUTH[@]}" "${TFC_API}/organizations/${TFC_ORG}/varsets" \
    -d "$(jq -n '{data: {type: "varsets", attributes: {name: "platform-tokens", global: true}}}')" \
    | jq -r '.data.id')"
  r "Created variable set platform-tokens (${VARSET_ID})"
fi
VARSET_VARS=$(curl -s "${TFC_AUTH[@]}" "${TFC_API}/varsets/${VARSET_ID}/vars")

t "2.7. Seeding the platform tokens"
GITHUB_TOKEN_VAR_ID="$(echo "${VARSET_VARS}" | jq -r '.data[] | select(.attributes.key=="GITHUB_TOKEN") | .id' | head -n1)"
VAR_BODY="$(jq -n --arg value "${GITHUB_TOKEN}" '{data: {type: "vars", attributes: {key: "GITHUB_TOKEN", value: $value, category: "env", hcl: false, sensitive: true}}}')"
if [[ -n "${GITHUB_TOKEN_VAR_ID}" ]]; then
  curl -s -X PATCH "${TFC_AUTH[@]}" "${TFC_API}/varsets/${VARSET_ID}/vars/${GITHUB_TOKEN_VAR_ID}" -d "${VAR_BODY}" >/dev/null
  r "Updated GITHUB_TOKEN"
else
  curl -s -X POST "${TFC_AUTH[@]}" "${TFC_API}/varsets/${VARSET_ID}/vars" -d "${VAR_BODY}" >/dev/null
  r "Added GITHUB_TOKEN"
fi

TFE_TOKEN_VAR_ID="$(echo "${VARSET_VARS}" | jq -r '.data[] | select(.attributes.key=="TFE_TOKEN") | .id' | head -n1)"
VAR_BODY="$(jq -n --arg value "${TFC_TOKEN}" '{data: {type: "vars", attributes: {key: "TFE_TOKEN", value: $value, category: "env", hcl: false, sensitive: true}}}')"
if [[ -n "${TFE_TOKEN_VAR_ID}" ]]; then
  curl -s -X PATCH "${TFC_AUTH[@]}" "${TFC_API}/varsets/${VARSET_ID}/vars/${TFE_TOKEN_VAR_ID}" -d "${VAR_BODY}" >/dev/null
  r "Updated TFE_TOKEN"
else
  curl -s -X POST "${TFC_AUTH[@]}" "${TFC_API}/varsets/${VARSET_ID}/vars" -d "${VAR_BODY}" >/dev/null
  r "Added TFE_TOKEN"
fi

CLOUDFLARE_TOKEN_VAR_ID="$(echo "${VARSET_VARS}" | jq -r '.data[] | select(.attributes.key=="CLOUDFLARE_API_TOKEN") | .id' | head -n1)"
VAR_BODY="$(jq -n --arg value "${CF_API_TOKEN}" '{data: {type: "vars", attributes: {key: "CLOUDFLARE_API_TOKEN", value: $value, category: "env", hcl: false, sensitive: true}}}')"
if [[ -n "${CLOUDFLARE_TOKEN_VAR_ID}" ]]; then
  curl -s -X PATCH "${TFC_AUTH[@]}" "${TFC_API}/varsets/${VARSET_ID}/vars/${CLOUDFLARE_TOKEN_VAR_ID}" -d "${VAR_BODY}" >/dev/null
  r "Updated CLOUDFLARE_API_TOKEN"
else
  curl -s -X POST "${TFC_AUTH[@]}" "${TFC_API}/varsets/${VARSET_ID}/vars" -d "${VAR_BODY}" >/dev/null
  r "Added CLOUDFLARE_API_TOKEN"
fi

r "GITHUB_TOKEN, TFE_TOKEN, and CLOUDFLARE_API_TOKEN shared with every workspace via platform-tokens"

# ══════════════════════════════════════════════════════════════════
# Phase 3: Imports — render bootstrap.tf from the collected IDs
# ══════════════════════════════════════════════════════════════════

h "Phase 3: Imports"

t "3.1. Deriving import addresses"
export GCP_DEFAULT_PROJECT
export GCP_SA_EMAIL="${SA_EMAIL}"
export TFC_ENV_NAME="mgt"
export TFC_PROJ_ID="${TFC_PROJECT_ID#prj-}"
export TFC_WS_NAME="${GCP_DEFAULT_PROJECT}"
export TFC_WSID="${TFC_WORKSPACE_ID}"
r "Import addresses derived"

t "3.2. Rendering bootstrap.tf from template"
envsubst < "${BOOTSTRAP_DIR}/imports.tf.tmpl" > "${INFRA_DIR}/bootstrap.tf"
printf '\nimport {\n  to   = module.environment["mgt"].google_folder.this\n  id   = "%s"\n}\n' "${FOLDER_ID}" >> "${INFRA_DIR}/bootstrap.tf"
for svc in "${DEVOPS_SERVICES[@]}"; do
  printf '\nimport {\n  to   = module.project["mgt"].google_project_service.this["%s-%s"]\n  id   = "%s/%s.googleapis.com"\n}\n' \
    "${GCP_DEFAULT_PROJECT}" "${svc}" "${GCP_DEFAULT_PROJECT}" "${svc}" >> "${INFRA_DIR}/bootstrap.tf"
done
r "Rendered bootstrap.tf — $(wc -l < "${INFRA_DIR}/bootstrap.tf") lines"

# ══════════════════════════════════════════════════════════════════
# Phase 4: Deploy
# ══════════════════════════════════════════════════════════════════

h "Phase 4: Deploy"

t "4.1. Initialising Terraform against workspace ${GCP_DEFAULT_PROJECT}"
export TF_WORKSPACE="${GCP_DEFAULT_PROJECT}"
export TFE_TOKEN="${TFC_TOKEN}"
GITHUB_TOKEN="$(gh auth token)"
export GITHUB_TOKEN
export CLOUDFLARE_API_TOKEN="${CF_API_TOKEN}"
terraform -chdir="${INFRA_DIR}" init -backend-config="organization=${TFC_ORG}"
r "Initialised"

t "Running Terraform apply to import existing + deploy non-existing resources"
terraform -chdir="${INFRA_DIR}" apply -auto-approve
r "Deploy complete"

r "Bootstrap complete — the platform now runs from main via TFC"

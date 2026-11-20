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

for tool in gcloud terraform jq git gh envsubst yq; do
  command -v "${tool}" >/dev/null || die "${tool} not found on PATH"
done

# ══════════════════════════════════════════════════════════════════
# Config
# ══════════════════════════════════════════════════════════════════

GCP_DOMAIN=$(yq -r '.organisation.gcp.domain' "${ENV_DIR}/organisation.yaml")
GCP_ORG_NAME=$(yq -r '.organisation.gcp.name' "${ENV_DIR}/organisation.yaml")
GCP_BILLING_ID=$(yq -r '.organisation.gcp.billing' "${ENV_DIR}/organisation.yaml")
TFC_ORG=$(yq -r '.organisation.tfe.organisation' "${ENV_DIR}/organisation.yaml")
TFC_HOSTNAME=$(yq -r '.organisation.tfe.hostname' "${ENV_DIR}/organisation.yaml")
GH_OWNER=$(yq -r '.organisation.gh.owner' "${ENV_DIR}/organisation.yaml")

[[ -n "${GCP_DOMAIN}" ]] || die "gcp domain not found in ${ENV_DIR}/organisation.yaml"
[[ -n "${GCP_ORG_NAME}" ]] || die "gcp organisation name not found in ${ENV_DIR}/organisation.yaml"
[[ -n "${GCP_BILLING_ID}" ]] || die "billing account ID not found in ${ENV_DIR}/organisation.yaml"
[[ -n "${TFC_ORG}" ]] || die "TFC organisation not found in ${ENV_DIR}/organisation.yaml"
[[ -n "${TFC_HOSTNAME}" ]] || die "TFC hostname not found in ${ENV_DIR}/organisation.yaml"
[[ -n "${GH_OWNER}" ]] || die "GitHub owner not found in ${ENV_DIR}/organisation.yaml"

PROJECTS_YAML="${ENV_DIR}/projects.yaml"
if ! grep -q '^  - name: devops$' "${PROJECTS_YAML}" || \
   ! grep -q 'type: mgt' "${PROJECTS_YAML}"; then
  die "mgt/devops project configuration missing from ${PROJECTS_YAML}"
fi
mapfile -t DEVOPS_SERVICES < <(yq -r '.projects[] | select(.name=="devops") | .services[]' "${PROJECTS_YAML}")
[[ ${#DEVOPS_SERVICES[@]} -gt 0 ]] || die "devops services missing from mgt/projects.yaml"

GCP_DEFAULT_PROJECT="ef-mgt-devops"
SA_NAME="sa-mgt-tfc"
SA_EMAIL="${SA_NAME}@${GCP_DEFAULT_PROJECT}.iam.gserviceaccount.com"

# ══════════════════════════════════════════════════════════════════
# Credentials
# ══════════════════════════════════════════════════════════════════

gh auth status >/dev/null 2>&1 || die "run gh auth login first (GitHub CLI authentication)"
GITHUB_TOKEN="$(gh auth token)"
[[ -n "${CF_API_TOKEN:-}" ]] || die "set CF_API_TOKEN (a Cloudflare token with Zone.DNS Edit on the apex zone)"
[[ -f ~/.terraform.d/credentials.tfrc.json ]] || die "run terraform login first (stores the Terraform Cloud token)"
TFC_TOKEN="$(jq -r '.credentials["app.terraform.io"].token' ~/.terraform.d/credentials.tfrc.json)"
[[ -n "${TFC_TOKEN}" && "${TFC_TOKEN}" != "null" ]] || die "no Terraform Cloud token in ~/.terraform.d/credentials.tfrc.json — run terraform login"
export TFE_TOKEN="${TFC_TOKEN}"

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

t "1.2. Verifying application-default credentials for the local apply"
if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
  r "No application-default credentials"
  die "Abort: run gcloud auth application-default login first"
fi
r "Application-default credentials present"

t "1.3. Checking the GCP organisation"
GCP_ORG_ID="$(gcloud organizations list \
  --filter="displayName=${GCP_ORG_NAME}" \
  --format='value(name)' 2>/dev/null | head -n1)"
[[ -n "${GCP_ORG_ID}" ]] || die "GCP organisation '${GCP_ORG_NAME}' not found or not accessible"
r "Resolved: ${GCP_ORG_ID}"

t "1.4. Checking the environment folder ef-mgt"
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

t "1.5. Checking the project ${GCP_DEFAULT_PROJECT}"
if gcloud projects describe "${GCP_DEFAULT_PROJECT}" >/dev/null 2>&1; then
  r "Project already exists"
else
  gcloud projects create "${GCP_DEFAULT_PROJECT}" \
    --folder="${FOLDER_ID}" >/dev/null 2>&1
  r "Created project"
fi
CURRENT_BILLING="$(gcloud billing projects describe "${GCP_DEFAULT_PROJECT}" \
  --format='value(billingAccountName)' 2>/dev/null | head -n1)"
if [[ "${CURRENT_BILLING#billingAccounts/}" == "${GCP_BILLING_ID}" ]]; then
  r "Billing already linked: ${GCP_BILLING_ID}"
elif gcloud billing projects link --help >/dev/null 2>&1; then
  gcloud billing projects link "${GCP_DEFAULT_PROJECT}" \
    --billing-account="billingAccounts/${GCP_BILLING_ID}" >/dev/null
  r "Billing linked: ${GCP_BILLING_ID}"
else
  t "gcloud billing projects link unavailable — link ${GCP_DEFAULT_PROJECT} to ${GCP_BILLING_ID} in the console"
fi
t "1.6. Enabling the required APIs"
for svc in "${DEVOPS_SERVICES[@]}"; do
  gcloud services enable "${svc}.googleapis.com" \
    --project="${GCP_DEFAULT_PROJECT}" --quiet >/dev/null
done
r "Enabled APIs: ${DEVOPS_SERVICES[*]}"

t "1.7. Creating the mgt identity ${SA_NAME}"
if gcloud iam service-accounts describe "${SA_EMAIL}" --project="${GCP_DEFAULT_PROJECT}" >/dev/null 2>&1; then
  r "Identity already exists"
else
  gcloud iam service-accounts create "${SA_NAME}" \
    --display-name="Management plane" \
    --project="${GCP_DEFAULT_PROJECT}" --quiet
  r "Created identity"
fi

# ══════════════════════════════════════════════════════════════════
# Phase 2: Terraform Cloud — seed the org, workspace, credentials
# ══════════════════════════════════════════════════════════════════

h "Phase 2: Terraform Cloud"

TFC_API="https://${TFC_HOSTNAME}/api/v2"
TFC_AUTH=( -H "Authorization: Bearer ${TFC_TOKEN}" -H "Content-Type: application/vnd.api+json" )

t "2.1. Checking the Terraform Cloud token"
TFC_ORG_ID="$(curl -s "${TFC_AUTH[@]}" "${TFC_API}/organizations/${TFC_ORG}" | jq -r '.data.id')"
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
TFC_PROJECT_ID="$(curl -s "${TFC_AUTH[@]}" "${TFC_API}/organizations/${TFC_ORG}/projects?page%5Bsize%5D=100" \
  | jq -r '.data[] | select(.attributes.name=="ef-mgt") | .id' | head -n1)"
if [[ -z "${TFC_PROJECT_ID}" ]]; then
  TFC_PROJECT_ID="$(curl -s -X POST "${TFC_AUTH[@]}" "${TFC_API}/organizations/${TFC_ORG}/projects" \
    -d "$(jq -n '{data: {type: "projects", attributes: {name: "ef-mgt"}}}')" \
    | jq -r '.data.id')"
  r "Created TFC project ef-mgt (${TFC_PROJECT_ID})"
else
  r "TFC project ef-mgt already exists (${TFC_PROJECT_ID})"
fi

t "2.4. Checking the workspace ${GCP_DEFAULT_PROJECT}"
TFC_WORKSPACE_ID="$(curl -s "${TFC_AUTH[@]}" "${TFC_API}/organizations/${TFC_ORG}/workspaces?page%5Bsize%5D=100" \
  | jq -r ".data[] | select(.attributes.name==\"${GCP_DEFAULT_PROJECT}\") | .id" | head -n1)"
if [[ -n "${TFC_WORKSPACE_ID}" ]]; then
  r "Workspace already exists (${TFC_WORKSPACE_ID})"
else
  TFC_WORKSPACE_ID="$(curl -s -X POST "${TFC_AUTH[@]}" "${TFC_API}/organizations/${TFC_ORG}/workspaces" \
    -d "$(jq -n --arg name "${GCP_DEFAULT_PROJECT}" --arg project "${TFC_PROJECT_ID}" \
      '{data: {type: "workspaces", attributes: {name: $name}, relationships: {project: {data: {type: "projects", id: $project}}}}}')" \
    | jq -r '.data.id')"
  r "Created workspace (${TFC_WORKSPACE_ID})"
fi

t "2.5. Setting workspace execution to local for the first apply"
EXEC_MODE="$(curl -s "${TFC_AUTH[@]}" "${TFC_API}/workspaces/${TFC_WORKSPACE_ID}" \
  | jq -r '.data.attributes."execution-mode"')"
if [[ "${EXEC_MODE}" != "local" ]]; then
  RESULT="$(curl -s -X PATCH "${TFC_AUTH[@]}" "${TFC_API}/workspaces/${TFC_WORKSPACE_ID}" \
    -d "$(jq -n '{data: {type: "workspaces", attributes: {"execution-mode": "local"}}}')" \
    | jq -r '.data.attributes."execution-mode" // empty')"
  [[ "${RESULT}" == "local" ]] || die "could not set the workspace to local execution (got: ${RESULT:-no response})"
  r "Switched to local execution for the first apply; Terraform switches it to remote"
else
  r "Workspace already runs locally for the first apply; Terraform switches it to remote"
fi

t "2.6. Rotating the organisation-wide token set platform-tokens"
VARSET_ID="$(curl -s "${TFC_AUTH[@]}" "${TFC_API}/organizations/${TFC_ORG}/varsets" \
  | jq -r '.data[] | select(.attributes.name=="platform-tokens") | .id' | head -n1)"
if [[ -n "${VARSET_ID}" ]]; then
  curl -s -X DELETE "${TFC_AUTH[@]}" "${TFC_API}/varsets/${VARSET_ID}" >/dev/null
  r "Removed previous token set"
fi

t "2.7. Seeding the platform tokens"
VAR_BODY="$(jq -n --arg gh "${GITHUB_TOKEN}" --arg tfe "${TFC_TOKEN}" --arg cf "${CF_API_TOKEN}" '{data: {type: "varsets", attributes: {name: "platform-tokens", global: true}, relationships: {vars: {data: [{type: "vars", attributes: {key: "GITHUB_TOKEN", value: $gh, category: "env", hcl: false, sensitive: true}}, {type: "vars", attributes: {key: "TFE_TOKEN", value: $tfe, category: "env", hcl: false, sensitive: true}}, {type: "vars", attributes: {key: "CLOUDFLARE_API_TOKEN", value: $cf, category: "env", hcl: false, sensitive: true}}]}}}}')"
VARSET_ID="$(curl -s -X POST "${TFC_AUTH[@]}" "${TFC_API}/organizations/${TFC_ORG}/varsets" -d "${VAR_BODY}" | jq -r '.data.id')"
[[ -n "${VARSET_ID}" && "${VARSET_ID}" != "null" ]] || die "failed to create the platform-tokens variable set"
r "platform-tokens (${VARSET_ID}) holds GITHUB_TOKEN, TFE_TOKEN, and CLOUDFLARE_API_TOKEN, shared with every workspace"

# ══════════════════════════════════════════════════════════════════
# Phase 3: Imports — render bootstrap.tf from the collected IDs
# ══════════════════════════════════════════════════════════════════

h "Phase 3: Imports"

t "3.1. Deriving import addresses"
export GCP_DEFAULT_PROJECT
export GCP_PROJ_NUM
export GCP_SA_EMAIL="${SA_EMAIL}"
export TFC_ENV_NAME="mgt"
export TFC_PROJ_ID="${TFC_PROJECT_ID#prj-}"
export TFC_WSID="${TFC_WORKSPACE_ID}"
r "Import addresses derived"

t "3.2. Rendering bootstrap.tf from template"
DEVOPS_SERVICES_JSON="$(jq -cn '$ARGS.positional' --args "${DEVOPS_SERVICES[@]}")"
DEVOPS_IMPORTS="$(jq -rn --arg project "${GCP_DEFAULT_PROJECT}" --argjson services "${DEVOPS_SERVICES_JSON}" '$services | map("import {\n  to   = module.project[\"\($project)\"].google_project_service.this[\"\($project)-\(.).googleapis.com\"]\n  id   = \"\($project)/\(.).googleapis.com\"\n}\n\n") | join("")')"
export FOLDER_ID
export DEVOPS_IMPORTS
envsubst < "${BOOTSTRAP_DIR}/imports.tf.tmpl" > "${INFRA_DIR}/bootstrap.tf"
r "Rendered bootstrap.tf — $(wc -l < "${INFRA_DIR}/bootstrap.tf") lines"

# ══════════════════════════════════════════════════════════════════
# Phase 4: Deploy
# ══════════════════════════════════════════════════════════════════

h "Phase 4: Deploy"

t "4.1. Initialising Terraform against workspace ${GCP_DEFAULT_PROJECT}"
export TFE_TOKEN="${TFC_TOKEN}"
export GITHUB_TOKEN
export CLOUDFLARE_API_TOKEN="${CF_API_TOKEN}"
terraform -chdir="${INFRA_DIR}" init -input=false -no-color -backend-config="organization=${TFC_ORG}" > "${BOOTSTRAP_DIR}/init.txt" 2>&1 || {
  cat "${BOOTSTRAP_DIR}/init.txt" >&2
  die "terraform init failed — full log: ${BOOTSTRAP_DIR}/init.txt"
}
r "Initialised (${BOOTSTRAP_DIR}/init.txt)"

t "4.2. Planning the first apply"
terraform -chdir="${INFRA_DIR}" plan -no-color -out=tfplan > "${BOOTSTRAP_DIR}/plan.txt" 2>&1
r "Plan written: ${BOOTSTRAP_DIR}/plan.txt — share it for review before approving"
read -r -p "Approve the plan above? [yes/no] " REPLY
[[ "${REPLY}" == "yes" ]] || die "apply declined"
r "Plan approved"

t "4.3. Applying the approved plan"
terraform -chdir="${INFRA_DIR}" apply tfplan
rm -f "${INFRA_DIR}/tfplan"
r "Deploy complete"

r "Bootstrap complete — the platform now runs from main via TFC"

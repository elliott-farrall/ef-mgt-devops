#!/usr/bin/env bash
set -euo pipefail

# ── Bootstrap: cloud landing zone bring-up ────────────────────────
# 1) Google Cloud   — seed: folder, project, APIs, mgt identity + key
# 2) Terraform Cloud — seed: project, workspace, credential variables
# 3) Imports        — render bootstrap.tf from the collected IDs
# 4) Deploy         — single apply importing + creating everything
# 5) Close out      — revoke the temporary credentials
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

[[ -n "${TF_TOKEN_APP_TERRAFORM_IO:-}" ]] || die "set TF_TOKEN_APP_TERRAFORM_IO (a user API token whose owner has authorised the TFC GitHub App)"
[[ -n "${GITHUB_TOKEN:-}" ]] || die "set GITHUB_TOKEN (a fine-grained PAT with repo administration on ${GH_OWNER})"
[[ -n "${CF_API_TOKEN:-}" ]] || die "set CF_API_TOKEN (a Cloudflare token with Zone.DNS Edit on ${GCP_DOMAIN})"

GCP_DEFAULT_PROJECT="ef-mgt-devops"
SA_NAME="sa-mgt-tfc"
SA_EMAIL="${SA_NAME}@${GCP_DEFAULT_PROJECT}.iam.gserviceaccount.com"
SA_KEY="/tmp/${SA_NAME}.json"

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
for svc in "${DEVOPS_SERVICES[@]}"; do
  gcloud services enable "${svc}.googleapis.com" --project="${GCP_DEFAULT_PROJECT}"
  r "Enabled API: ${svc}"
done

t "1.6. Checking the mgt identity ${SA_NAME}"
if gcloud iam service-accounts list --project="${GCP_DEFAULT_PROJECT}" --format="value(email)" \
   | grep -q "^${SA_NAME}@"; then
  r "${SA_NAME} already exists"
else
  gcloud iam service-accounts create "${SA_NAME}" \
    --display-name="Management plane" \
    --project="${GCP_DEFAULT_PROJECT}"
  r "Created ${SA_NAME}"
fi
r "SA email: ${SA_EMAIL}"

t "1.7. Granting the first-apply permissions to ${SA_NAME}"
gcloud organizations add-iam-policy-binding "${GCP_ORG_ID#organizations/}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/resourcemanager.organizationAdmin" --condition=None >/dev/null
r "Granted organisation admin (managed by Terraform)"
gcloud projects add-iam-policy-binding "${GCP_DEFAULT_PROJECT}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/owner" >/dev/null
r "Granted project owner on ${GCP_DEFAULT_PROJECT} (managed by Terraform)"
gcloud billing accounts add-iam-policy-binding "${GCP_BILLING_ACCOUNT}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/billing.admin" >/dev/null
r "Granted billing admin (temporary — removed after the first apply)"

t "1.8. Creating the first-apply key for ${SA_NAME}"
if gcloud iam service-accounts keys list --iam-account="${SA_EMAIL}" \
   --format="value(name)" --project="${GCP_DEFAULT_PROJECT}" 2>/dev/null | grep -q "/keys/"; then
  r "Key already exists"
else
  gcloud iam service-accounts keys create "${SA_KEY}" \
    --iam-account="${SA_EMAIL}" >/dev/null
  r "Created key ${SA_KEY}"
fi

# ══════════════════════════════════════════════════════════════════
# Phase 2: Terraform Cloud — seed the org, workspace, credentials
# ══════════════════════════════════════════════════════════════════

h "Phase 2: Terraform Cloud"

TFC_OPTS="--address https://${TFC_HOSTNAME} --org ${TFC_ORG} --output-format json"
TFC_API="https://${TFC_HOSTNAME}/api/v2"
TFC_AUTH=( -H "Authorization: Bearer ${TF_TOKEN_APP_TERRAFORM_IO}" -H "Content-Type: application/vnd.api+json" )

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

t "2.5. Checking workspace credential variables"
seed_var() {
  local key="$1" value="$2" category="$3" sensitive="$4"
  local body existing
  existing="$(curl -s "${TFC_AUTH[@]}" "${TFC_API}/workspaces/${TFC_WORKSPACE_ID}/vars" \
    | jq -r ".data[] | select(.attributes.key==\"${key}\" and .attributes.category==\"${category}\") | .id" | head -n1)"
  body=$(jq -n --arg key "${key}" --arg value "${value}" --arg category "${category}" --argjson sensitive "${sensitive}" \
    '{data: {type: "vars", attributes: {key: $key, value: $value, category: $category, hcl: false, sensitive: $sensitive}}}')
  if [[ -n "${existing}" ]]; then
    curl -s -X PATCH "${TFC_AUTH[@]}" "${TFC_API}/vars/${existing}" -d "${body}" >/dev/null
    r "Updated ${key}"
  else
    curl -s -X POST "${TFC_AUTH[@]}" "${TFC_API}/workspaces/${TFC_WORKSPACE_ID}/vars" -d "${body}" >/dev/null
    r "Created ${key}"
  fi
}
seed_var "GOOGLE_CREDENTIALS" "$(cat "${SA_KEY}")" "env" true
r "Mgt key seeded — the first apply authenticates with it; Terraform adds the WIF variables for every run after it"

t "2.6. Checking the organisation-wide token set platform-tokens"
VARSET_ID="$(curl -s "${TFC_AUTH[@]}" "${TFC_API}/organizations/${TFC_ORG}/varsets" \
  | jq -r '.data[] | select(.attributes.name=="platform-tokens") | .id' | head -n1)"
if [[ -z "${VARSET_ID}" ]]; then
  VARSET_ID="$(curl -s -X POST "${TFC_AUTH[@]}" "${TFC_API}/organizations/${TFC_ORG}/varsets" \
    -d "$(jq -n '{data: {type: "varsets", attributes: {name: "platform-tokens", global: true}}}')" \
    | jq -r '.data.id')"
  r "Created variable set platform-tokens (${VARSET_ID})"
fi
upsert_varset_var() {
  local key="$1" value="$2"
  local var_id body
  var_id="$(curl -s "${TFC_AUTH[@]}" "${TFC_API}/varsets/${VARSET_ID}/vars" \
    | jq -r --arg key "${key}" '.data[] | select(.attributes.key==$key) | .id' | head -n1)"
  body="$(jq -n --arg key "${key}" --arg value "${value}" \
    '{data: {type: "vars", attributes: {key: $key, value: $value, category: "env", hcl: false, sensitive: true}}}')"
  if [[ -n "${var_id}" ]]; then
    curl -s -X PATCH "${TFC_AUTH[@]}" "${TFC_API}/varsets/${VARSET_ID}/vars/${var_id}" -d "${body}" >/dev/null
    r "Updated ${key}"
  else
    curl -s -X POST "${TFC_AUTH[@]}" "${TFC_API}/varsets/${VARSET_ID}/vars" -d "${body}" >/dev/null
    r "Added ${key}"
  fi
}
upsert_varset_var "GITHUB_TOKEN" "${GITHUB_TOKEN}"
upsert_varset_var "TFE_TOKEN" "${TF_TOKEN_APP_TERRAFORM_IO}"
upsert_varset_var "CLOUDFLARE_API_TOKEN" "${CF_API_TOKEN}"
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
r "Rendered bootstrap.tf — $(wc -l < "${INFRA_DIR}/bootstrap.tf") lines"

# ══════════════════════════════════════════════════════════════════
# Phase 4: Deploy
# ══════════════════════════════════════════════════════════════════

h "Phase 4: Deploy"

t "4.1. Initialising Terraform against workspace ${GCP_DEFAULT_PROJECT}"
export TF_ADDRESS="https://${TFC_HOSTNAME}"
export TF_CREDENTIALS="env"
export TF_HTTP_USERNAME="token"
export TF_HTTP_PASSWORD="${TF_TOKEN_APP_TERRAFORM_IO}"
export TF_WORKSPACE="${GCP_DEFAULT_PROJECT}"
terraform -chdir="${INFRA_DIR}" init -backend-config="organization=${TFC_ORG}"
r "Initialised"

t "Running Terraform apply to import existing + deploy non-existing resources"
terraform -chdir="${INFRA_DIR}" apply -auto-approve
r "Deploy complete"

# ══════════════════════════════════════════════════════════════════
# Phase 5: Close out — revoke the temporary credentials
# ══════════════════════════════════════════════════════════════════

h "Phase 5: Close out"

t "5.1. Removing the first-apply credentials from the workspace"
GOOGLE_CREDS_VAR_ID="$(curl -s "${TFC_AUTH[@]}" "${TFC_API}/workspaces/${TFC_WORKSPACE_ID}/vars" \
  | jq -r '.data[] | select(.attributes.key=="GOOGLE_CREDENTIALS" and .attributes.category=="env") | .id' | head -n1)"
if [[ -n "${GOOGLE_CREDS_VAR_ID}" ]]; then
  curl -s -X DELETE "${TFC_AUTH[@]}" "${TFC_API}/vars/${GOOGLE_CREDS_VAR_ID}" >/dev/null
  r "Deleted GOOGLE_CREDENTIALS workspace variable"
fi

t "5.2. Revoking the first-apply key"
shred -u "${SA_KEY}" 2>/dev/null || rm -f "${SA_KEY}"
r "Deleted the key file"

t "5.3. Revoking the temporary billing admin grant"
gcloud billing accounts remove-iam-policy-binding "${GCP_BILLING_ACCOUNT}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/billing.admin" >/dev/null
r "Revoked billing admin — the managed costsManager grant remains"

r "Bootstrap complete — the platform now runs from main via TFC"

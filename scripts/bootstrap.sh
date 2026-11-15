#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INFRA_DIR="${REPO_ROOT}/infrastructure"

die() { printf '\033[1;31mfatal: %s\n' "$*" >&2; exit 1; }
h()   { printf '%s\n' "$*"; }       # header, no indent
t()   { printf '├── %s\n' "$*"; }   # substep action
r()   { printf '│   └── %s\n' "$*"; } # result (aligned under action)

PROJECT_NAME="ef-mgt-devops"

# ══════════════════════════════════════════════════════════════════
# Prerequisites — verify required tools are on PATH
# ══════════════════════════════════════════════════════════════════

h "Prerequisites"

t "Verifying dependencies"

command -v gcloud     >/dev/null || die "gcloud not found on PATH"
command -v terraform  >/dev/null || die "terraform not found on PATH"
command -v jq         >/dev/null || die "jq not found on PATH"
command -v git        >/dev/null || die "git not found on PATH"
command -v tfccli     >/dev/null || die "tfccli not found on PATH"
command -v envsubst   >/dev/null || die "envsubst not found on PATH"

r "All available"

# ══════════════════════════════════════════════════════════════════
# Phase 1 — Google Cloud setup
# ══════════════════════════════════════════════════════════════════

h "Phase 1: Google Cloud"

# ── 1.1 Verify authentication ──────────────────────────────────────

t "1.1. Verify gcloud authentication"

GCP_ACCOUNT="$(
  gcloud auth list \
    --filter=status:ACTIVE \
    --format='value(account)' \
    2>/dev/null || true)"

if [[ -z "${GCP_ACCOUNT}" ]]; then
  r "Not authenticated — run: gcloud init"
  die "Abort: authenticate with gcloud first"
fi

r "Authenticated as ${GCP_ACCOUNT}"

# ── 1.2 Resolve GCP organisation ───────────────────────────────────

t "1.2. Resolving GCP organisation"

GCP_ORGANISATION_ID="$(
  gcloud organizations list \
    --filter="display_name=elliott-farrall.phd" \
    --format='value(name)' \
    2>/dev/null | head -n1)"

if [[ -z "${GCP_ORGANISATION_ID}" ]]; then
  r "Organisation not accessible"
  die "Abort: account '${GCP_ACCOUNT}' lacks access to the organisation"
fi

GCP_ORGANISATION="folders/${GCP_ORGANISATION_ID#organizations/}"
r "Resolved: ${GCP_ORGANISATION_ID} (${GCP_ORGANISATION})"

# ── 1.3 Ensure GCP project exists ──────────────────────────────────

t "1.3. Ensuring project"

if gcloud projects describe "${PROJECT_NAME}" >/dev/null 2>&1; then
  r "Project already exists"
else
  gcloud projects create "${PROJECT_NAME}" \
    --folder="${GCP_ORGANISATION_ID#/folders/}" \
    --billing-account="ef-billing" \
    --set-as-default
  r "Created project"
fi

r "Project ID: ${PROJECT_NAME}"

# ── 1.4 Enable required APIs ───────────────────────────────────────

t "1.4. Enabling required APIs on ${PROJECT_NAME}"

gcloud services enable iam.googleapis.com          --project="${PROJECT_NAME}"
gcloud services enable serviceusage.googleapis.com --project="${PROJECT_NAME}"
gcloud services enable cloudbilling.googleapis.com --project="${PROJECT_NAME}"
gcloud services enable dns.googleapis.com          --project="${PROJECT_NAME}"
gcloud services enable compute.googleapis.com      --project="${PROJECT_NAME}"
r "Enabled 5 API(s)"

# ── 1.5 Ensure service account exists ──────────────────────────────

t "1.5. Ensuring service account sa-mgt-tfc"

GCP_SA_EXISTS="$(
  gcloud iam service-accounts list \
    --project="${PROJECT_NAME}" \
    --format="value(email)" \
    2>/dev/null | grep -c "sa-mgt-tfc@" || true)"

if [[ "${GCP_SA_EXISTS}" -gt 0 ]]; then
  r "Service account already exists"
else
  gcloud iam service-accounts create \
    sa-mgt-tfc \
    --display-name="Management plane" \
    --project="${PROJECT_NAME}"
  r "Created sa-mgt-tfc"
fi

# ══════════════════════════════════════════════════════════════════
# Phase 2 — Terraform Cloud setup
# ══════════════════════════════════════════════════════════════════

h "Phase 2: Terraform Cloud"

# ── 2.1 Verify token and org access ────────────────────────────────

t "2.1. Verify Terraform Cloud token"

TFC_OPTS="--address https://app.terraform.io --org elliott-farrall --output-format json"

if [[ -z "${TF_TOKEN_APP_TERRAFORM_IO:-}" ]]; then
  r "Token not set — set TF_TOKEN_APP_TERRAFORM_IO environment variable"
  die "Abort: set TF_TOKEN_APP_TERRAFORM_IO first"
fi

TFC_ORGANISATION_ID="$(
  tfccli organizations get \
    --name elliott-farrall \
    ${TFC_OPTS} | jq -r '.data.id' \
    2>/dev/null || true)"

if [[ -z "${TFC_ORGANISATION_ID}" || "${TFC_ORGANISATION_ID}" == "null" ]]; then
  r "Organisation inaccessible"
  die "Abort: token lacks access to the TFC organisation"
fi

r "Authenticated, organisation elliott-farrall accessible"

# ── 2.2 Ensure TFC project exists ──────────────────────────────────

t "2.2. Ensuring TFC project ef-mgt"

TFC_PROJECT_ID="$(
  tfccli projects list \
    ${TFC_OPTS} | jq -r 'select(.name=="ef-mgt") | .id' \
    | head -n1 || true)"

if [[ -z "${TFC_PROJECT_ID}" || "${TFC_PROJECT_ID}" == "null" ]]; then
  TFC_PROJECT_ID="$(
    tfccli projects create \
      --name ef-mgt \
      ${TFC_OPTS} | jq -r '.id')"
  r "Created TFC project ef-mgt (${TFC_PROJECT_ID})"
else
  r "TFC project already exists (${TFC_PROJECT_ID})"
fi

r "Project ID: ${TFC_PROJECT_ID}"

# ── 2.3 Ensure workspace exists ────────────────────────────────────

t "2.3. Ensuring workspace for ${PROJECT_NAME}"

TFC_WORKSPACE_ID="$(
  tfccli workspaces list \
    ${TFC_OPTS} \
    --project-id "${TFC_PROJECT_ID}" | jq -r \
    "select(.name==\"${PROJECT_NAME}\") | .id" \
    | head -n1 || true)"

if [[ -n "${TFC_WORKSPACE_ID}" ]]; then
  r "Workspace already exists (${TFC_WORKSPACE_ID})"
else
  TFC_WORKSPACE_ID="$(
    tfccli workspaces create \
      --name "${PROJECT_NAME}" \
      --project-id "${TFC_PROJECT_ID}" \
      ${TFC_OPTS} | jq -r '.id')"
  r "Created workspace (${TFC_WORKSPACE_ID})"
fi

r "Workspace ID: ${TFC_WORKSPACE_ID}"

# ══════════════════════════════════════════════════════════════════
# Phase 3 — Render imports from template
# ══════════════════════════════════════════════════════════════════

h "Phase 3: Render imports"

# ── 3.1 Render imports.tf ──────────────────────────────────────────

t "3.1. Rendering imports.tf from template"

envsubst < "${INFRA_DIR}/imports.tf.tmpl" > "${INFRA_DIR}/imports.tf"
r "Rendered imports.tf — $(wc -l < "${INFRA_DIR}/imports.tf") lines"

# ══════════════════════════════════════════════════════════════════
# Phase 4 — Deploy
# ══════════════════════════════════════════════════════════════════

h "Phase 4: Deploy"

# ── 4.1 Initialise Terraform ───────────────────────────────────────

t "4.1. Initialising Terraform against workspace ${PROJECT_NAME}"

export TF_ADDRESS="https://app.terraform.io"
export TF_WORKSPACE="${PROJECT_NAME}"
export TF_VAR_environment="mgt"

terraform -chdir="${INFRA_DIR}" init \
  -backend-config="organization=elliott-farrall"

r "Initialised"

# ── 4.2 Run Terraform apply ────────────────────────────────────────

t "4.2. Running terraform apply to import existing + deploy new resources"

terraform -chdir="${INFRA_DIR}" apply -auto-approve

r "Deploy complete"

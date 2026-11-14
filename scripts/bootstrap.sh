#!/usr/bin/env bash
set -euo pipefail

# ── Bootstrap: EF platform bring-up ────────────────────────────────
# Reads config from environments/mgt/*.yaml. Secrets stay in env vars.
# Scripts create, Terraform adopts, the plan proves.
# ──────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_DIR="$REPO_ROOT/environments/mgt"

log()  { printf '\033[1;36m[ef]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[ef] warn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[ef] fatal:\033[0m %s\n' "$*" >&2; exit 1; }

# ── Read config from YAML ─────────────────────────────────────────

ORG_DOMAIN=$(nix-shell -p python3Packages.pyyaml --run "python3 -c 'import yaml; print(yaml.safe_load(open(\"$ENV_DIR/organisation.yaml\"))[\"organisation\"][\"gcp\"][\"domain\"])'" 2>/dev/null | grep -v warning)
TFC_ORG=$(nix-shell -p python3Packages.pyyaml --run "python3 -c 'import yaml; print(yaml.safe_load(open(\"$ENV_DIR/organisation.yaml\"))[\"organisation\"][\"tfe\"][\"organisation\"])'" 2>/dev/null | grep -v warning)
TFC_HOSTNAME=$(nix-shell -p python3Packages.pyyaml --run "python3 -c 'import yaml; print(yaml.safe_load(open(\"$ENV_DIR/organisation.yaml\"))[\"organisation\"][\"tfe\"][\"hostname\"])'" 2>/dev/null | grep -v warning)
GH_OWNER=$(nix-shell -p python3Packages.pyyaml --run "python3 -c 'import yaml; print(yaml.safe_load(open(\"$ENV_DIR/organisation.yaml\"))[\"organisation\"][\"gh\"][\"owner\"])'" 2>/dev/null | grep -v warning)

INFRA_ENVS=$(nix-shell -p python3Packages.pyyaml --run "python3 -c 'import yaml,json; d=yaml.safe_load(open(\"$ENV_DIR/environments.yaml\")); print(\" \".join([e[\"name\"] for e in d[\"environments\"] if e.get(\"type\")==\"infrastructure\"]))'" 2>/dev/null | grep -v warning)

[[ -n "$ORG_DOMAIN" ]] || die "organisation domain not found in $ENV_DIR/organisation.yaml"
[[ -n "$TFC_ORG" ]] || die "TFC organisation not found in $ENV_DIR/organisation.yaml"
[[ -n "$TFC_HOSTNAME" ]] || die "TFC hostname not found in $ENV_DIR/organisation.yaml"
[[ -n "$GH_OWNER" ]] || die "GitHub owner not found in $ENV_DIR/organisation.yaml"
[[ -n "$INFRA_ENVS" ]] || die "no infrastructure environments found in $ENV_DIR/environments.yaml"

# ── Prerequisites ──────────────────────────────────────────────────

require_env() {
  local v
  for v in "$@"; do
    [[ -n "${!v:-}" ]] || die "Required environment variable $v is unset."
  done
}

require_env EF_BILLING_ACCOUNT TFC_TOKEN

log "preflight: tools"
for t in gcloud terraform jq curl git; do
  command -v "$t" >/dev/null || die "$t not found on PATH"
done

API="https://${TFC_HOSTNAME}/api/v2"
HDR=(-H "Authorization: Bearer $TFC_TOKEN" -H "Content-Type: application/vnd.api+json")
tfc() { curl -sf "${HDR[@]}" "$@"; }

# ── Step 1: Seed GCP ───────────────────────────────────────────────

log "seeding GCP for organisation $ORG_DOMAIN"

ORG="$(gcloud organizations list --filter="display_name=${ORG_DOMAIN}" --format='value(name)' | head -n1)"
[[ -n "$ORG" ]] || die "organisation not resolved — set EF_ORG_ID or EF_ORG_DOMAIN"

folder_id_for() {
  gcloud resource-manager folders list --organization="$ORG" \
    --filter="displayName=$1" --format="value(name)" 2>/dev/null | head -n1
}

ensure_folder() {
  local name="$1" parent="$2" existing
  existing="$(folder_id_for "$name")"
  if [[ -n "$existing" ]]; then
    log "folder $name already exists ($existing)"
  else
    log "creating folder $name under $parent"
    existing="$(gcloud resource-manager folders create \
      --display-name="$name" --parent="$parent" --organization="$ORG" \
      --format="value(name)")"
  fi
  log "folder $name → $existing"
}

LANDING="ef-mgt-devops"

ensure_folder "ef-root" "organizations/$ORG"
ROOT="folders/$(folder_id_for ef-root)"
for f in ef-mgt ef-hub ef-app; do ensure_folder "$f" "$ROOT"; done
APP="folders/$(folder_id_for ef-app)"
for f in ef-dev ef-pre ef-prd; do ensure_folder "$f" "$APP"; done

if gcloud projects describe "$LANDING" >/dev/null 2>&1; then
  log "project $LANDING already exists"
else
  log "creating project $LANDING"
  gcloud projects create "$LANDING" \
    --folder="$ROOT" \
    --billing-account="$EF_BILLING_ACCOUNT" \
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

ORG_ID="$(tfc "$API/organizations/$TFC_ORG" | jq -r '.data.id')"

ensure_project() {
  local name="$1" id
  id="$(tfc "$API/organizations/$TFC_ORG/projects?search[name]=$name" \
        | jq -r --arg n "$name" '.data[] | select(.attributes.name==$n) | .id' | head -n1)"
  if [[ -n "$id" ]]; then
    log "project $name already exists ($id)"
  else
    log "creating project $name"
    id="$(tfc -X POST "$API/projects" \
          -d "$(jq -n --arg n "$name" --arg o "$ORG_ID" '{data:{type:"projects",attributes:{name:$n,settings:{execution-mode:"remote"},auto-destroy-activity-duration:-1},relationships:{organization:{data:{type:"organizations",id:$o}}}}}')" \
          | jq -r '.data.id')"
  fi
  log "project $name → $id"
}

for p in ef-mgt ef-hub; do ensure_project "$p"; done

LANDING_WS="ef-mgt-devops"
LANDING_PROJ="$(tfc "$API/organizations/$TFC_ORG/projects?search[name]=ef-mgt" \
                | jq -r --arg n "ef-mgt" '.data[] | select(.attributes.name==$n) | .id' | head -n1)"

ws_id="$(tfc "$API/organizations/$TFC_ORG/workspaces?search[name]=$LANDING_WS&project_ids=$LANDING_PROJ" \
         | jq -r --arg n "$LANDING_WS" '.data[] | select(.attributes.name==$n) | .id' | head -n1)"
if [[ -n "$ws_id" ]]; then
  log "workspace $LANDING_WS already exists ($ws_id)"
else
  log "creating workspace $LANDING_WS in project ef-mgt"
  ws_id="$(tfc -X POST "$API/workspaces" \
        -d "$(jq -n --arg n "$LANDING_WS" --arg pid "$LANDING_PROJ" \
          '{data:{type:"workspaces",attributes:{name:$n,project-id:$pid}}}' \
        )" \
        | jq -r '.data.id')"
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
for f in ef-root ef-mgt ef-hub ef-app ef-dev ef-pre ef-prd; do
  fid="$(gcloud resource-manager folders list --organization="$ORG" \
         --filter="displayName=$f" --format="value(name)" 2>/dev/null | head -n1)"
  import_one "module.google-folder.google_folder.tree[\"$f\"]" "folders/${fid}"
done

# Landing project
proj_num="$(gcloud projects describe "$LANDING" --format='value(projectNumber)' 2>/dev/null | head -n1)"
[[ -n "$proj_num" ]] || die "project $LANDING not found"
import_one "module.google-project[\"$LANDING\"].google_project.this" "$proj_num"

# TFC projects
for p in ef-mgt ef-hub; do
  pid="$(tfc "$API/organizations/$TFC_ORG/projects?search[name]=$p" \
         | jq -r --arg n "$p" '.data[] | select(.attributes.name==$n) | .id' | head -n1)"
  [[ -n "$pid" ]] || die "TFC project $p not found"
  import_one "module.tfe-project[\"$p\"].tfe_project.this" "prj-$pid"
done

# Workspace + settings
ws_id="$(tfc "$API/organizations/$TFC_ORG/workspaces?search[name]=$LANDING_WS&project_ids=$LANDING_PROJ" \
         | jq -r --arg n "$LANDING_WS" '.data[] | select(.attributes.name==$n) | .id' | head -n1)"
[[ -n "$ws_id" ]] || die "workspace $LANDING_WS not found"
import_one "module.tfe-workspace[\"$LANDING_WS\"].tfe_workspace.this" "$ws_id"
import_one "module.tfe-workspace[\"$LANDING_WS\"].tfe_workspace_settings.this" "$ws_id"

# GitHub repo
import_one "module.github-repository[\"$LANDING\"].github_repository.this" "$LANDING"


log "import complete — now prove the loop: terraform plan must show no diff"

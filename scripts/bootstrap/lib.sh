#!/usr/bin/env bash
# Bootstrap helpers: logging + inventory.yaml updates.
# Orchestration only — validation belongs to Terraform (docs/conventions.md).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INVENTORY="$REPO_ROOT/scripts/bootstrap/inventory.yaml"

log()  { printf '\033[1;36m[ef]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[ef] warn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[ef] fatal:\033[0m %s\n' "$*" >&2; exit 1; }

require_env() {
  local v
  for v in "$@"; do
    [[ -n "${!v:-}" ]] || die "Required environment variable $v is unset (see docs/bootstrap.md prerequisites)."
  done
}

# inventory_set KEY VALUE — create/update a top-level key in inventory.yaml.
inventory_set() {
  local key="$1" value="$2"
  touch "$INVENTORY"
  if grep -q "^${key}:" "$INVENTORY"; then
    sed -i "s|^${key}:.*|${key}: \"${value}\"|" "$INVENTORY"
  else
    printf '%s: "%s"\n' "$key" "$value" >> "$INVENTORY"
  fi
  log "inventory: ${key} = ${value}"
}

inventory_get() {
  grep "^$1:" "$INVENTORY" | sed 's/^[^:]*: *"\{0,1\}\([^"]*\)"\{0,1\}[[:space:]]*$/\1/' || true
}

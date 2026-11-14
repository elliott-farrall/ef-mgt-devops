# Conventions

Binding for this repository and every future `ef-*` repository.

## Naming

- Everything lower kebab-case, prefixed `ef-`: repos `ef-<env>-<name>`, GCP
  projects `ef-<env>-<name>`, folders `ef-<env>` under `ef-root`, TFC projects
  mirror the folders, workspaces mirror repos (`app` adds `-<env>`).
- Service accounts: `sa-<scope>-<purpose>` (`sa-mgt-tfc`, `sa-adm-bootstrap`).
- Mandatory labels on every label-capable resource: `environment`,
  `managed_by: terraform`, `repository`, `tfc_project`.

## Layout

- `infrastructure/` — all Terraform (the TFC working directory); purpose files
  (`providers.tf`, `variables.tf`, `locals.tf`, `main.tf`, `outputs.tf`);
  repo-local modules under `modules/`.
- `environments/<name>/` — YAML inputs, one directory per environment slot,
  split by concern, merged alphabetically in `locals.tf`.
- `scripts/` — bash for orchestration only (bootstrap, maintenance); never
  validation logic.
- `docs/` — runbooks and conventions; `README.md` points here.

## Code rules

- Exactly one top-level variable: `environment`, no default.
- All derivation in `locals.tf`; resources and modules consume locals only.
- `main.tf` is composition only — no hand-written resources beyond trivial glue.
- Validation is Terraform-native: `validation`, `precondition`, and `check`
  blocks must fail bad input at plan time.
- Modules stay repo-local until code must cross repositories; then extract to
  `ef-lib-*` and publish by git tag to the private registry
  (namespace `elliott-farrall`), consumers pin `version`.
- Secrets never appear in YAML or code — TFC sensitive variables only.
- Cross-stack reads via `terraform_remote_state`, never hardcoded IDs.

## Review rules

- Steady state is code-only: console changes are read-only; any manual change
  is drift and must be adopted or reverted within one working day.
- Every change arrives as a PR; CI runs fmt/validate/plan; merge to `main`
  triggers the TFC run. GitHub Actions holds no cloud apply credentials.
- Structural resources (folders, projects, workspaces, zones) may only be
  created by TFC under the matching scope — enforced by org policies and IAM,
  not convention.

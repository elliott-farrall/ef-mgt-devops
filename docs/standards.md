# Standards

Binding for this repository and every future `ef-*` repository.

## Naming

- Everything lower kebab-case, prefixed `ef-`: repos `ef-<env>-<name>`, GCP
  projects `ef-<env>-<name>`, folders `ef-<env>` under `ef-root`, TFC projects
  mirror the folders, workspaces mirror repos (`app` adds `-<env>`).
- In code, use the short platform names: `cf` for Cloudflare, `gh` for GitHub
  (`cf.yaml`, `modules/cf`, `03-cf.sh`). Provider resource names keep their
  upstream spelling (`cloudflare_zone`). Long names only in prose.
- Service accounts: `sa-<scope>-<purpose>` (`sa-mgt-tfc`, `sa-adm-bootstrap`).
- Mandatory labels on every label-capable resource: `environment`,
  `managed_by: terraform`, `repository`, `tfc_project`.

## Layout

- `infrastructure/` — all Terraform (the TFC working directory); purpose files
  (`providers.tf`, `variables.tf`, `locals.tf`, `main.tf`, `outputs.tf`);
  repo-local modules under `modules/`.
- `environments/<name>/` — YAML inputs, one directory per environment slot,
  split by concern, merged alphabetically in `locals.tf`.
- `bootstrap/` — top-level bash for orchestration only (seed, adopt,
  maintenance): numbered scripts, `00-lib.sh` helpers, `run.sh`
  orchestrator; never validation logic. `inventory.yaml` is transient —
  deleted by `05-cleanup.sh` at close-out.
- `docs/` — exactly three files: `design.md` (decisions and rationale),
  `standards.md` (binding rules), `bootstrap.md` (bring-up procedure);
  `README.md` points here. New documentation extends these three; it does not
  add a fourth.

## Code rules

- Exactly one top-level variable: `environment`, no default.
- No comments at the top of files — the filename and `docs/` say what a file
  is for; comments inside bodies explain only the non-obvious.
- Each `environments/<name>/*.yaml` has one top-level key matching the
  filename (`gcp:`, `gh:`, `tfc:`, `cf:`) with its variables nested
  underneath; `locals.tf` merges the files and exposes the namespaces.
- Platform-wide inputs are **registries**: folders, projects, workspaces,
  repositories, and zones are lists of entries keyed by name in the YAML, and
  modules iterate them with `for_each`. Provisioning anything new is a data
  change here — never a new variable, and never a hardcoded singular
  resource.
- All derivation in `locals.tf`; resources and modules consume locals only,
  and modules receive their platform's slice of the config, not the whole map.
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

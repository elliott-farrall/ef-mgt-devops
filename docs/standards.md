# Standards

Binding for this repository and every future `ef-*` repository.

## Naming

- Everything lower kebab-case, prefixed `ef-`: repos `ef-<env>-<name>`, GCP
  projects `ef-<env>-<name>`, folders `ef-<env>` under `ef-root`, TFC projects
  mirror the folders, workspaces mirror repos (`app` adds `-<env>`).
- In code, use the short platform names: `cf` for Cloudflare, `gh` for GitHub
  (`cf.yaml`, `modules/cf`, `03-cf.sh`). Provider resource names keep their
  upstream spelling (`cloudflare_zone`). Long names only in prose.
- Service accounts: `sa-<scope>-<purpose>`. `sa-adm-tfc` is the platform
  administration identity — org-level roles, used by the `ef-mgt-devops`
  workspace for high-level operations. `sa-<env>-tfc` (`sa-mgt-tfc`,
  `sa-hub-tfc`, `sa-dev-tfc`, `sa-pre-tfc`, `sa-prd-tfc`) are plane
  identities, each declared under the folder it acts on; only
  organisation- and billing-scope bindings go in the root
  `service_accounts` list. Identities are hosted by the landing project.
  `sa-adm-bootstrap` is the exception: bootstrap-only, never declared,
  deleted at close-out.
- PR branches: `<type>/<kebab-name>`, type one of `feature`, `fix`, `hotfix`,
  `chore`, `docs`, `refactor`, `test`, `perf`, `build`, `ci`, `revert`.
  Enforced by the `branch-name` CI check, which is required on `main`.
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
- `.schemas/environment/` — JSON Schema (draft-07, in YAML) mirroring the
  `environments/<env>/` filenames; every registry change lands in its schema
  in the same PR. Instances bind to them with a `yaml-language-server`
  modeline — one of the two permitted comment forms.
- `docs/` — exactly three files: `design.md` (decisions and rationale),
  `standards.md` (binding rules), `bootstrap.md` (bring-up procedure);
  `README.md` points here. New documentation extends these three; it does not
  add a fourth.

## Code rules

- Exactly one top-level variable: `environment`, no default.
- No comments in code, YAML, or config files — none. Two functional
  exceptions only: shell shebangs and `yaml-language-server` modelines.
  Everything a file does is said by its name, its code, or `docs/`;
  work-in-progress notes belong in the runbook, never in the tree.
- Each `environments/<name>/*.yaml` has one top-level key matching the
  filename (`gcp:`, `gh:`, `tfc:`, `cf:`) with its variables nested
  underneath; `locals.tf` merges the files and exposes the namespaces.
- YAML files use **block style only** — no flow/JSON syntax (`{...}` mappings
  or `[...]` inline sequences). One entry per line keeps diffs reviewable.
- Optional inputs with platform defaults are omitted from the YAML; the
  defaults live in `locals.tf`: `cf.zones[].plan` = `free`,
  `tfc.hostname` = `app.terraform.io`,
  `tfc.projects[].workspaces[].working_directory` = `infrastructure`,
  `auto_apply` = `false`.
- Platform-wide inputs are **registries**: the GCP folder tree
  (`folders:` — entries of `name`, optional `projects` (leaf IDs), and
  optional nested `folders` of the same shape), the TFC project tree
  (`projects:` — entries of `name` with optional nested `workspaces`),
  GitHub repositories, and Cloudflare zones. Provisioning anything new is a
  data change here — never a new variable, and never a hardcoded singular
  resource. `locals.tf` unrolls the trees into flat keyed nodes (GCP: 4
  folder levels, enforced by a `check` block; TFC: fixed two levels, with a
  validation guarding project references); recursive modules are banned —
  their cache layout breaks `terraform init` reruns.
- Registry entries inherit platform defaults declared in `locals.tf` and may
  override them with optional blocks (`settings:`, `protection:`); modules
  receive the merged, keyed maps — never raw YAML entries.
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

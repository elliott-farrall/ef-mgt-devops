# Standards

Binding for this repository and every future `ef-*` repository.

## Naming

- Everything lower kebab-case, prefixed `ef-`: repos `ef-<env>-<name>`, GCP
  projects `ef-<env>-<name>`, folders `ef-<env>` under `ef-root`, TFC projects
  mirror the folders, workspaces mirror repos (`app` adds `-<env>`).
- In code, use the short platform names: `gh` for GitHub, `cf` for Cloudflare
  if it ever returns (`gh.yaml`, `modules/gh-repository`). Provider resource
  names keep their upstream spelling (`github_repository`). Long names only
  in prose.
- Service accounts: `sa-<scope>-<purpose>`. `sa-adm-tfc` is the platform
  administration identity — org-level roles, used by the `ef-mgt-devops`
  workspace for high-level operations. `sa-<env>-tfc` (`sa-mgt-tfc`,
  `sa-hub-tfc`, `sa-dev-tfc`, `sa-pre-tfc`, `sa-prd-tfc`) are plane
  identities, bound only at their own folders. All identities and every
  binding live in one place: the `gcp.iam` list, where each entry names
  its hosting `project` and every binding carries its explicit scope
  (`folder:`, `project:`, `organisation`, `billing`). All platform
  identities live in the landing project `ef-mgt-devops`, declared like
  any other project in the tree. `sa-adm-bootstrap` is the exception:
  bootstrap-only, never declared, deleted at close-out.
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
  filename (`gcp:`, `gh:`, `tfc:`) with its variables nested
  underneath; `locals.tf` merges the files and exposes the namespaces.
- YAML files use **block style only** — no flow/JSON syntax (`{...}` mappings
  or `[...]` inline sequences). One entry per line keeps diffs reviewable.
- Values are **plain scalars — no quote marks** in `environments/` and
  `bootstrap/inventory.yaml`. A value that would need quoting is reworded
  instead (no `: ` inside strings — the repository description uses `-`
  for exactly this reason). `.schemas/` is exempt: JSON Schema regex
  patterns and prose descriptions legitimately carry quotes.
- Optional inputs with platform defaults are omitted from the YAML; the
  defaults live in `locals.tf`: `tfc.hostname` = `app.terraform.io`,
  `tfc.projects[].workspaces[].working_directory` = `infrastructure`,
  `tfc.projects[].workspaces[].auto_apply` = `false`,
  `gcp.billing` currency = GBP in the module.
- Platform-wide inputs are **registries**: GCP `folders` and `projects`
  (flat entries of `{ name, parent }` — the parent pointer carries the
  hierarchy, `root` marks children of the organisation root), TFC
  `projects` (entries of `name` with optional nested `workspaces`),
  GitHub repositories, DNS zones, and billing budgets.
  Provisioning anything new is a data change here — never a new variable,
  and never a hardcoded singular resource. Hierarchies live in data as
  parent pointers, never as nested YAML: HCL has no recursion, so every
  level of nesting buys a flatten chain in `locals.tf`. Recursive
  modules are banned — their cache layout breaks `terraform init` reruns.
- Registry entries inherit platform defaults declared in `locals.tf` and may
  override them with optional blocks (`settings:`, `protection:`); modules
  receive the merged, keyed maps — never raw YAML entries.
- All derivation in `locals.tf`; resources and modules consume locals only,
  and modules receive their config slice, not the whole merged map.
- Modules are named `<platform>-<resource>` in the singular
  (`gcp-folders`, `gcp-project`, `gcp-service-account`, `gcp-iam-binding`,
  `gcp-budget`, `gcp-dns`, `tfc-project`, `tfc-workspace`,
  `gh-repository`): each provisions one instance of a resource family.
  Multiplicity comes from `for_each` at the call site, never from looping
  inside the module.
- Module call grammar: `source`, then `for_each`; blank line; inputs;
  blank line; `depends_on`. The `for_each` local is named after the
  module, pluralised: `gcp-project` ← `local.gcp_projects`,
  `gcp-iam-binding` ← `local.gcp_iam_bindings`. A module without
  `for_each` takes one local of the same name (`gcp-folders` ←
  `local.gcp_folders`).
- Every module call binds to exactly one local: `for_each` iterates a
  `local.*` collection, and each argument is a pass-through of
  `each.value`, a key, or a bare data/local reference. No comprehensions,
  ternaries, or index lookups in `main.tf` — resolution lives in
  `locals.tf`, so `main.tf` is pure wiring and `locals.tf` is the only
  place to read to understand what a call receives.
- The iterated object's keys are exactly the module's input names, and
  every argument reads `each.value.<input-name>` — never `each.key`,
  never a bare `each.value`, never a constant. The loop element *is* the
  argument list, so the call reads as a mirror of the local and the
  module's variables.
- A self-referential resource graph (the folder tree) is the single
  exception: it loops with `for_each` **inside** one `gcp-folders` call — the plural name is deliberate, the module consumes the whole collection,
  because Terraform can order resources against each other but never
  sibling instances of one module set. The tree arrives as one flat
  collection, `local.gcp_folders` (name → `{ parent }`); parent
  references are validated by the module's own checks.
- Data sources live in the root `data.tf`; modules receive resolved IDs
  and names, keeping them thin resource wrappers. Cross-module wiring is
  done only in the root `main.tf`.
- Cross-module ordering is stated with explicit `depends_on` even where
  value references already imply it: folders → projects → service
  accounts → bindings, projects → budgets, tfc-projects → workspaces.
  The wiring graph in `main.tf` should be readable without tracing
  expressions.
- `check` blocks live in `checks.tf` — root or module — never in
  `main.tf`. A check belongs in the module that owns the invariant; the
  root `checks.tf` keeps cross-registry referential integrity
  (project→folder, iam→project, budget→project, account uniqueness).
- `main.tf` is composition only — no hand-written resources beyond trivial glue.
- Validation is Terraform-native: `validation`, `precondition`, and `check`
  blocks must fail bad input at plan time.
- Modules stay repo-local until code must cross repositories; then extract to
  `ef-lib-*` and publish by git tag to the private registry
  (namespace `elliott-farrall`), consumers pin `version`.
- Secrets never appear in YAML or code — TFC sensitive variables only.
- Cross-stack references resolve by name via provider data sources
  (`google_folders`, `google_dns_managed_zone`, …) — never hardcoded IDs, and no
  `terraform_remote_state` coupling: the management plane publishes no
  outputs.

## Review rules

- Steady state is code-only: console changes are read-only; any manual change
  is drift and must be adopted or reverted within one working day. The one
  sanctioned exception: installing the TFC GitHub App itself — a console
  action done once; its installation ID then makes every workspace's
  repository link pure Terraform.
- Every change arrives as a PR; CI runs fmt/validate/plan; merge to `main`
  triggers the TFC run. GitHub Actions holds no cloud apply credentials.
- Structural resources (folders, projects, workspaces, zones) may only be
  created by TFC under the matching scope — enforced by org policies and IAM,
  not convention.

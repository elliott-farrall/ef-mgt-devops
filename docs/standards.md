# Standards

Binding for this repository and every future `ef-*` repository.

## Naming

- Everything lower kebab-case, prefixed `ef-`: repos `ef-<env>-<name>`, GCP
  projects `ef-<env>-<name>`, folders `ef-<env>` under `ef-root`, TFC projects
  mirror the folders. Workspaces are registry entries with an explicit
  `environment`; `repo` defaults to the workspace name, so one repository
  can carry several environments (`ef-app-identity-dev/pre/prd` all build
  `ef-app-identity`).
- Platform identifiers are the provider names: `google`, `tfe`, `github`
  (`modules/google-project`). Not the product abbreviations
  — `gcp`, `tfc`, `gh` are retired. Product names survive only inside data
  values (`sa-<env>-tfc`, `tfc-<env>`, `ef-<env>-tfc`).
- Service accounts: `sa-<env>-tfc`, **derived** — one per `terraform`-type
  environment; `blank` environments are folders only. Each derived identity gets the core
  roles required for its function: `projectCreator` and `editor` at its own
  folder, `serviceAccountUser` and `dns.admin` at the landing project. The
  stack's own environment is detected as the management one and receives the
  platform roles on top: `folderAdmin` and `projectCreator` at `ef-root`,
  `browser` at the organisation, `billing.user` at the billing account.
  There is no separate administration identity — `sa-mgt-tfc` runs the
  platform and the management plane. The landing project is the one
  project marked `default: true` — exactly one, today `ef-mgt-devops` —
  and it hosts every identity pool `ef-<env>-tfc`, every service account,
  and every DNS zone. The marker sits on the project, not the
  environment: identity and domain always know where they go. `sa-adm-bootstrap` is the exception: bootstrap-only, never
  declared, deleted at close-out.
- Workspace names carry the folder scope, because federation admits by
  folder, not by name: a workspace of a terraform-type environment starts
  `ef-<env>-`; a workspace deploying into a lane environment ends `-<env>`.
  The naming convention *is* the contract — the CEL condition and the
  `attribute.environment/<env>` stamp are derived from it, never declared.
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
  deleted by `04-cleanup.sh` at close-out.
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
- Config files are named by setup concern, not by platform:
  `organisation.yaml` (who we operate as — org domain, region, TFC and
  GitHub handles), `billing.yaml` (billing account and budget alerts),
  `domain.yaml` (DNS zones and platform records), and `environments.yaml`
  (a list, one entry per folder, each hosting `projects`; the one
  infrastructure project marked `default: true` is the platform home). Each file has one top-level key
  matching the filename; `locals.tf` merges the files and exposes the
  namespaces.
- **A project is one entry with a type**: declaring
  `environments[].projects[]` with `type: software` mints just the GitHub
  repository; `type: infrastructure` adds the TFC workspace (in the
  environment's project `ef-<env>`) and the GCP project in folder
  `ef-<env>`; `type: module` adds a private TFC registry module published
  from the repository by git tag. Name = repository = workspace = GCP
  project id; the repository is the name with a trailing `-<lane>` suffix
  stripped, so one repo can carry `ef-app-identity-dev|pre|prd` while
  `ef-mgt-devops` owns its repo outright. `settings:`/`protection:`
  override repository policy once per repo. `default: true` on exactly
  one infrastructure project marks the platform home.
- YAML files use **block style only** — no flow/JSON syntax (`{...}` mappings
  or `[...]` inline sequences). One entry per line keeps diffs reviewable.
- Values are **plain scalars — no quote marks** in `environments/` and
  `bootstrap/inventory.yaml`. A value that would need quoting is reworded
  instead (no `: ` inside strings — the repository description uses `-`
  for exactly this reason). `.schemas/` is exempt: JSON Schema regex
  patterns and prose descriptions legitimately carry quotes.
- Optional inputs with platform defaults are omitted from the YAML; the
  defaults live in `locals.tf`: `environments.list[].projects[].working_directory` = `infrastructure`,
  `environments.list[].projects[].auto_apply` = `false`,
  `billing` currency = GBP in the module.
- Platform-wide inputs are **registries**: `environments.list` — one entry
  per folder, `{ name, type, parent? }`, ancestors before children; the
  parent pointer carries the hierarchy and the parentless entry hangs off
  the organisation root; `type: terraform` owns the TFC project `ef-<name>`
  with optional nested `workspaces`; `projects.gcp` and `projects.github`;
  DNS zones; billing budgets. Names are derived, never repeated: folder
  `ef-<name>`, service account `sa-<name>-tfc`, provider `tfc-<name>`,
  federation issuer `https://<organisation.tfe.hostname>` — the TFC API
  endpoint and the OIDC trust are one required value.
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
- Modules are named `<provider>-<resource>` — the provider's own name and
  the main resource deployed (`google-folder`, `google-project`,
  `google-service-account`, `google-workload-identity-pool`,
  `google-workload-identity-provider`, `google-iam-member`, `google-billing-budget`,
  `google-dns-managed-zone`, `tfe-project`, `tfe-workspace`,
  `tfe-registry-module`, `github-repository`): each provisions one instance of a resource family.
  Multiplicity comes from `for_each` at the call site, never from looping
  inside the module.
- Module outputs are mechanical: one output per resource the module
  creates, exporting the whole resource object — named after the resource
  type (`google_folder`, `tfe_workspace`, plus `tfe_variable_<name>` where
  a module holds several of one type). No pre-extracted or renamed
  attributes; the consumer picks what it needs.
- Module call grammar: `source`, then `for_each`; blank line; inputs;
  blank line; `depends_on`. The `for_each` local is named after the
  module, pluralised: `google-project` ← `local.google_projects`,
  `google-iam-member` ← `local.google_iam_members`. A module without
  `for_each` takes one local of the same name (`google-folder` ←
  `local.google_folders`).
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
  exception: it loops with `for_each` **inside** one `google-folder` call — the plural name is deliberate, the module consumes the whole collection,
  because Terraform can order resources against each other but never
  sibling instances of one module set. The tree arrives as one flat
  collection, `local.google_folders` (name → `{ parent }`); parent
  references are validated by the module's own checks.
- Data sources always live in a `data.tf` — root or module — never in
  `main.tf`. A module's lookup belongs in that module's `data.tf`; the
  root `data.tf` holds only lookups shared by several modules
  (`google_organization`, `google_billing_account`). Cross-module wiring
  is done only in the root `main.tf`.
- Cross-module ordering is stated with explicit `depends_on` even where
  value references already imply it: folders → projects → service
  accounts → workload identities → bindings, projects → budgets, tfe-projects → project workspaces.
  The wiring graph in `main.tf` should be readable without tracing
  expressions.
- `check` blocks live in `checks.tf` — root or module — never in
  `main.tf`. A check belongs in the module that owns the invariant; the
  root `checks.tf` keeps cross-registry referential integrity
  (project→folder, environment→parent, workspace→environment,
  landing→project, zone→project, budget→project).
- `main.tf` is composition only — no hand-written resources, with no
  exceptions since the pool became a module: pools
  (`google-workload-identity-pool`, one per environment), providers
  (`google-workload-identity-provider`, one per federated identity,
  minting tokens into exactly one service account), and every further
  binding (`google-iam-member`) all sit behind modules.
- Validation is Terraform-native: `validation`, `precondition`, and `check`
  blocks must fail bad input at plan time.
- Modules stay repo-local until code must cross repositories; then extract to
  `ef-lib-*` and publish by git tag to the private registry
  (namespace `elliott-farrall`), consumers pin `version`.
- Secrets never appear in YAML or code — TFC sensitive variables only.
- Cross-stack references resolve by name via provider data sources
  (`google_folders`, `google_dns_managed_zone`, …) — never hardcoded IDs, and no
  `terraform_remote_state` coupling: the management plane publishes no
  outputs. The federation chain is convention-locked: workspace in
  environment `<env>` authenticates through provider `tfc-<env>` and
  receives `WIF_PROVIDER` as a run environment variable; the SA of that environment holds
  the `workloadIdentityUser` binding.

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

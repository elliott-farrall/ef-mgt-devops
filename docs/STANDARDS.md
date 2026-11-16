# Standards

Binding for this repository and every future `ef-*` repository.

## Naming

- Everything lower kebab-case, prefixed `ef-`: config declares only the
  project *suffix*; the full name `ef-<env>-<suffix>` is generated from the
  environment the entry sits under and becomes the workspace, the GCP
  project id, and the default repository name. TFC projects are `ef-<env>`. A
  repository shared across environments is named explicitly with `repo:`
  (e.g. `ef-dev-identity`, `ef-pre-identity` and `ef-prd-identity` all
  building `ef-app-identity`). Libraries generate `ef-lib-<name>`.
- Platform identifiers are the provider names: `google`, `tfe`, `github`
  (`modules/google-project`). Not the product abbreviations
  — `gcp`, `tfc`, `gh` are retired. Product names survive only inside data
  values (`sa-<env>-tfc`, `tfc-<env>`, `ef-<env>-tfc`).
- Service accounts: `sa-<env>-tfc`, **derived** — one per environment. Each
  derived identity gets the core roles required for its function:
  `projectCreator` and `editor` on its own future projects,
  `serviceAccountUser` and `dns.admin` at the landing project. The
  stack's own environment is detected as the management one and receives the
  platform roles on top: organisation admin, `projectOwner` on the landing
  project, `billing.user` at the billing account.
  There is no separate administration identity — `sa-mgt-tfc` runs the
  platform and the management plane. The landing project is the one
  project marked `default: true` — exactly one, today `ef-mgt-devops` —
  and it hosts every identity pool `ef-<env>-tfc`, every service account,
  and every DNS zone. The marker sits on the project, not the
  environment: identity and domain always know where they go. `sa-adm-bootstrap` is the exception: bootstrap-only, never
  declared, deleted at close-out.
- Workspace names carry the environment scope: every workspace starts
  `ef-<env>-` — its environment prefix is
  generated, so admission can never drift from the naming. The naming
  convention *is* the contract — the CEL condition and the
  `attribute.environment/<env>` stamp are derived from it, never declared.
- PR branches: `<type>/<kebab-name>`, type one of `feature`, `fix`, `hotfix`,
  `chore`, `docs`, `refactor`, `test`, `perf`, `build`, `ci`, `revert`.
  Enforced by the `branch-name` CI check, which is required on `main`.
- Mandatory labels on every label-capable resource: `environment`,
  `managed_by: terraform`, `repository`, `tfc_project`.

## Layout

- `infrastructure/` — all Terraform (the TFC working directory); purpose files
  (`providers.tf`, `variables.tf`, `locals.tf`, `main.tf`, `data.tf`,
  `checks.tf`); repo-local modules under `modules/`, each `main.tf`,
  `variables.tf`, `outputs.tf` (+ `data.tf`/`checks.tf` when owned). The root
  declares no outputs: the platform publishes none.
- `environments/<name>/` — YAML inputs, one directory per environment slot,
  split by concern, merged alphabetically in `locals.tf`.
- `scripts/` — bash for orchestration only (seed, adopt, deploy); never
  validation logic. `inventory.yaml` is transient — deleted at close-out.
- `.schemas/environment/` — JSON Schema (draft-07, in YAML) mirroring the
  `environments/<env>/` filenames; every registry change lands in its schema
  in the same PR. Instances bind to them with a `yaml-language-server`
  modeline — one of the two permitted comment forms.
- `docs/` — exactly two files: `DESIGN.md` (decisions and rationale),
  `STANDARDS.md` (binding rules); `README.md` points here. New documentation
  extends these; it does not add a third.

## Code rules

- Exactly one top-level variable: `environment`, no default.
- No comments in code, YAML, or config files — none. Two functional
  exceptions only: shell shebangs and `yaml-language-server` modelines.
  Everything a file does is said by its name, its code, or `docs/`;
  work-in-progress notes belong in the runbook, never in the tree.
- Config files are named by setup concern, not by platform:
  `organisation.yaml` (who we operate as — org domain, region, TFC and
  GitHub handles), `billing.yaml` (billing account and budget alerts),
  `domain.yaml` (domains and platform records), `environments.yaml`
  (a flat list, one entry per environment, each hosting `projects`; the one
  project marked `default: true` is the platform home), and `modules.yaml`
  (a flat list of Terraform module repositories outside any environment).
  Each file has one
  top-level key matching the filename; `locals.tf` merges the files and
  exposes the namespaces.
- **A project is one entry**: declaring
  `environments[].projects[]` mints the GitHub repository, the TFC
  workspace (in the environment's TFC project `ef-<env>`), and the GCP
  project directly under the organisation root. `default: true` on exactly
  one project marks the platform home. `settings:`/`protection:` override
  repository policy once per repo. Example: `mgt` + suffix `devops` yields
  repo, workspace and GCP project `ef-mgt-devops`.
- **A module is one entry**: declaring `modules[]` mints the repository
  `ef-lib-<name>` and a private TFC registry module (module name `<name>`,
  published from the repository by git tag). It creates no workspace, no
  service account, and no GCP project.
- YAML files use **block style only** — no flow/JSON syntax (`{...}` mappings
  or `[...]` inline sequences). One entry per line keeps diffs reviewable.
- Values are **plain scalars — no quote marks** in `environments/` and
  `bootstrap/inventory.yaml`. A value that would need quoting is reworded
  instead (no `: ` inside strings — the repository description uses `-`
  for exactly this reason). `.schemas/` is exempt: JSON Schema regex
  patterns and prose descriptions legitimately carry quotes.
- Optional inputs with platform defaults are omitted from the YAML; the
  defaults live in `locals.tf`: `environments[].projects[].working_directory` = `infrastructure`,
  `environments[].projects[].auto_apply` = `false`,
  `billing` currency = GBP in the module.
- Registry entries inherit platform defaults declared in `locals.tf` and may
  override them with optional blocks (`settings:`, `protection:`); modules
  receive the merged, keyed maps — never raw YAML entries.
- All derivation in `locals.tf`; resources and modules consume locals only,
  and modules receive their config slice, not the whole merged map.
- Modules are named `<provider>-<resource>` — the provider's own name and
  the main resource deployed (`google-project`,
  `google-service-account`, `google-workload-identity-pool`,
  `google-workload-identity-provider`, `google-iam-member`, `google-billing-budget`,
  `google-dns-managed-zone`, `tfe-project`, `tfe-workspace`,
  `tfe-registry-module`, `github-repository`): each provisions one instance of a resource family.
  Multiplicity comes from `for_each` at the call site, never from looping
  inside the module.
- Module outputs are mechanical: one output per resource the module
  creates, exporting the whole resource object — named after the resource
  type (`google_project`, `tfe_workspace`, plus `tfe_variable_<name>` where
  a module holds several of one type). No pre-extracted or renamed
  attributes; the consumer picks what it needs.
- Module call grammar: `source`, then `for_each`; blank line; inputs;
  blank line; `depends_on`. The `for_each` local is named after the
  module, pluralised: `google-project` ← `local.google_projects`,
  `google-iam-member` ← `local.google_iam_members`.
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
- A self-referential resource graph is the single
  exception: it loops with `for_each` **inside** one module call — the plural name is deliberate, the module consumes the whole collection,
  because Terraform can order resources against each other but never
  sibling instances of one module set.
- Data sources always live in a `data.tf` — root or module — never in
  `main.tf`. A module's lookup belongs in that module's `data.tf`; the
  root `data.tf` holds only lookups shared by several modules
  (`google_organization`, `google_billing_account`). Cross-module wiring
  is done only in the root `main.tf`.
- Cross-module ordering is stated with explicit `depends_on` even where
  value references already imply it: projects → pools and
  service accounts → providers → bindings, projects → budgets and zones,
  github-repositories → workspaces and registry modules.
  The wiring graph in `main.tf` should be readable without tracing
  expressions.
- `check` blocks live in `checks.tf` — root or module — never in
  `main.tf`. A check belongs in the module that owns the invariant; the
  root `checks.tf` keeps cross-registry referential integrity
  (project and repository names unique, exactly one default project,
  budget scope→project).
- `main.tf` is composition only — no hand-written resources, with no
  exceptions: pools
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
  (`google_dns_managed_zone`, …) — never hardcoded IDs, and no
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
- Structural resources (projects, workspaces, zones) may only be
  created by TFC under the matching scope — enforced by org policies and IAM,
  not convention.

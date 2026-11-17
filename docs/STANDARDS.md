# Standards

Binding for this repository and every future `ef-*` repository. Decisions
and rationale live in [DESIGN.md](DESIGN.md); this document states the rules
themselves. Keep it current: every change to structure or convention lands
here in the same PR that makes it.

## Environments

- Five flat infrastructure environments: `mgt`, `hub`, `dev`, `pre`, `prd`.
  Each is top-level directly under the organisation root — no environment
  types, no parent pointers.
- Each environment owns, derived from its name: GCP folder `ef-<env>`
  directly under the organisation root, TFC project `ef-<env>`, service
  account `sa-<env>-tfc`, WIF pool `ef-<env>-tfc`, WIF provider
  `tfc-<env>`, and the workspaces of its projects. Every GCP project
  lives in its environment's folder.
- A project lives in exactly one environment. Cross-environment reuse flows
  through hub services and registry modules — never through shared
  projects.
- Exactly one project across all environments is marked `default: true`
  (today `ef-mgt-devops`): the **landing project**. It hosts every
  environment identity, every pool and provider, and every DNS zone. The
  marker sits on the project, not the environment.
- The landing project is bootstrap-provisioned: created outside Terraform on
  first bring-up, then imported. Terraform never has to order anything
  before it.

## GCP

- The hierarchy is one folder per environment under the organisation root;
  every project is created inside its environment's folder. Environment
  separation is carried by folders, naming, workspaces, and IAM.
- One identity kind: `sa-<env>-tfc`, one per environment, minted from
  config. No separate administration identity — `sa-mgt-tfc` runs the
  platform and the management plane.
- Each environment identity gets the core roles required for its function:
  `projectCreator` and `editor` on the landing project, `serviceAccountUser`
  and `dns.admin` at the landing project. The management environment adds
  the platform roles on top: organisation admin, `projectOwner` on the
  landing project, `billing.user` at the billing account.
- Workload identity federation: TFC run → OIDC token → pool
  `ef-<env>-tfc`, provider `tfc-<env>`, issuer
  `https://<organisation.tfe.hostname>` — the TFC API endpoint and the OIDC
  trust are one required value. The attribute condition
  `assertion.workspace_name.startsWith("ef-<env>-")` and the
  `attribute.environment/<env>` stamp are derived from the naming
  convention, never declared. The pool principal holds
  `workloadIdentityUser` on the environment SA.
- Mandatory labels on every label-capable resource: `environment`,
  `managed_by: terraform`, `repository`.
- `prevent_destroy` on structural resources (projects, DNS zones).
- Billing budgets notify, they never cap. Budget currency is GBP, declared
  inside the `budget` module.

## GitHub

- Source of truth and CI validation; holds no cloud apply credentials. A
  compromised repository cannot touch infrastructure.
- Repositories are private with squash-merge only, branch deletion on
  merge, and vulnerability alerts enabled. `main` is governed by two
  repository rulesets, not classic branch protection:
  - **Enforcement** — no bypass for anyone, admin included: linear history,
    no force-pushes, no deletions, and strict status checks on
    `["ci / branch-name (pull_request)", "ci / terraform (pull_request)",
    "ci / yaml (pull_request)", "ci / shell (pull_request)"]` plus, for
    workspaces, `"Terraform Cloud / <workspace> (Predict)"` — a successful
    speculative TFC plan is required before merge.
  - **Review** — one required approving review and resolved conversation
    threads, dismissed on new pushes, squash merge only. The repository
    admin role bypasses this ruleset with `bypass_mode: pull_request`: the
    maintainer's own pull requests need no approval, but nobody — admins
    included — can push directly to `main`. Agents and collaborators
    always work through PRs and receive the maintainer's review.
  Per-repo overrides arrive as `settings:`/`protection:` on the entry.
- PR branches: `<type>/<kebab-name>`, type one of `feature`, `fix`,
  `hotfix`, `chore`, `docs`, `refactor`, `test`, `perf`, `build`, `ci`,
  `revert`. Enforced by the `branch-name` CI check, required on `main`.
- CI runs format checks, schema validation, shellcheck, and Terraform
  validate (no backend) — plan-only, no cloud credentials. TFC runs a
  speculative plan on every PR; a successful plan is a required status
  check. A merge to `main` starts the TFC run; GitHub Actions never
  applies. Merging stays manual — no auto-merge.
- The TFC GitHub App installation is the one sanctioned console action:
  done once, its installation name then makes every workspace link pure
  Terraform.

## Terraform Cloud

- TFC is the single deployment engine. All applies run under workspace
  identities with remote execution mode. Workspaces VCS-link to their
  GitHub repositories via the GitHub App installation.
- One TFC project per environment, `ef-<env>`; one workspace per project
  entry, named `ef-<env>-<suffix>` — its environment prefix is generated,
  so admission can never drift from the naming.
- Workspaces carry three injected variables: `environment` (terraform
  category — the deployment slot), `TFC_GCP_PROVIDER_AUTH = true`
  (enables HCP Terraform dynamic credentials for the Google provider),
  `TFC_GCP_WORKLOAD_IDENTITY_PROVIDER` (the full provider resource path),
  and `TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL` (the SA impersonated after token
  exchange). All four are derived; none is declared in YAML. These are the
  HCP Terraform dynamic-credentials contract — never replaced with
  non-standard variable names.
- Credentials reach every run through the organisation-wide variable set
  `platform-tokens` (`GITHUB_TOKEN`, `TFE_TOKEN` — sensitive, created and
  rotated by bootstrap, never in state). The landing workspace
  additionally holds, until its first apply completes, the temporary
  bootstrap `GOOGLE_CREDENTIALS` — deleted by bootstrap close-out.
  Tokens are user-bound by platform constraint, not by choice: team and
  organisation tokens cannot create GitHub-App-backed workspaces.
  yamllint runs with default rules; the only disabled rule is
  line-length, forced by unbreakable DNS record values.
- Run policy per project entry: `auto_apply: true` for dev-style lanes,
  `false` (manual confirm) everywhere else. The policy is data, not code.

## Terraform code

- One top-level variable: `environment`, validated against the
  environment slots and the existence of `environments/<name>/`. A default
  is set situationally — the landing workspace needs one for its first run,
  before its `environment` variable exists; other stacks may omit it.
- Block types split into separate files: `locals.tf`, `data.tf`,
  `checks.tf`, `providers.tf`, `versions.tf`, and so on — one purpose per
  filename. The one exception is resources and module blocks: they live in
  `main.tf` or may be split into category files `_<category>.tf`
  (`_github.tf`, `_google.tf`, `_tfe.tf`, `_identity.tf`, `_iam.tf`,
  `_repository.tf`) — used in the multi-resource modules to keep resources
  organised; single-resource modules keep plain `main.tf`.
- Code is organised by function, not by platform. Five repo-local modules,
  each packaging one deliverable across every platform it touches:
  `environment` (TFC project, service account, WIF pool and provider, SA
  impersonation binding, IAM bindings), `project` (GitHub repository,
  branch protection, GCP project, APIs, TFC workspace and variables),
  `module` (GitHub repository, branch protection, private TFC registry
  module), `zone` (DNS managed zone and record sets), `budget` (billing
  budget alert). Multiplicity comes from `for_each` at the call site, never
  from looping inside the module.
- `locals.tf` holds, in order: `config` (the merged YAML), one top-level
  local per module — named after the module, plural, and used directly as
  that module call's `for_each` — and nothing else. Extra top-level locals
  are the rare exception, allowed only when a check or a data source needs
  them (today: `google_default_project`). Everything else is inlined.
- Every module call binds to exactly one local: `source`, then `for_each`;
  blank line; inputs; blank line; `depends_on`. Each argument is a
  pass-through of `each.value.<input-name>` — never `each.key`, never a
  bare `each.value`, never a constant. No comprehensions, ternaries, or
  index lookups in `main.tf` — resolution lives in `locals.tf`, so
  `main.tf` is pure wiring and `locals.tf` is the only place to read to
  understand what a call receives.
- The iterated object's keys are exactly the module's input names, and
  every argument reads `each.value.<input-name>`. The loop element *is* the
  argument list, so the call reads as a mirror of the local and the
  module's variables.
- Module inputs are config slices, not the whole merged map. Optional
  platform defaults live inside the owning module, merged with the
  caller-passed overrides: `working_directory` = `infrastructure` and
  `auto_apply` = `false` in `project`, repository and branch-protection
  defaults in `project` and `module`, `budget` currency = GBP in `budget`.
- Module outputs are mechanical: one output per resource the module
  creates, exporting the whole resource object — named after the resource
  type (`google_project`, `tfe_workspace`, plus `tfe_variable_<name>` where
  a module holds several of one type). No pre-extracted or renamed
  attributes; the consumer picks what it needs.
- Data sources always live in a `data.tf` — root or module — never in
  `main.tf`. A module's lookup belongs in that module's `data.tf`; the root
  `data.tf` holds only organisation-level lookups the platform does not
  create (`google_organization`, `google_billing_account`). This codebase
  creates its projects, so project data is never read back through data
  sources: WIF paths and identity references come from resource attributes
  (`google_iam_workload_identity_pool_provider.this.name`).
- Cross-module ordering is stated with explicit `depends_on` even where
  value references already imply it: environments → projects (workspaces
  bind to TFC projects and impersonate environment identities), projects →
  zones and budgets. Within modules, workspaces and registry modules depend
  on their own repository. The landing project needs no ordering: it
  pre-exists via bootstrap.
- A self-referential resource graph is the single exception to call-site
  `for_each`: it loops with `for_each` **inside** one module call, because
  Terraform can order resources against each other but never sibling
  instances of one module set.
- `check` blocks live in `checks.tf` — root or module — never in
  `main.tf`. A check belongs in the module that owns the invariant; the
  root `checks.tf` keeps cross-registry referential integrity (project and
  repository names unique, exactly one default project, budget
  scope→project).
- `main.tf` is composition only — no hand-written resources, no exceptions.
- Validation is Terraform-native: `validation`, `precondition`, and
  `check` blocks must fail bad input at plan time. Shell scripts only
  orchestrate — if a rule can be checked in HCL, it must be.

- Modules stay repo-local until code must cross repositories; then extract
  to `ef-lib-*` and publish by git tag to the private registry, consumers
  pin `version`.
- Secrets never appear in YAML or code — TFC sensitive variables only.
- Cross-stack references resolve by name via provider data sources — never
  hardcoded IDs, and no `terraform_remote_state` coupling: the management
  plane publishes no outputs. The federation chain is convention-locked:
  workspace in environment `<env>` authenticates through provider
  `tfc-<env>` and receives `TFC_GCP_WORKLOAD_IDENTITY_PROVIDER` as a run environment variable.
- Recursive modules are banned — their cache layout breaks `terraform init`
  reruns.

## Terraform naming

- Everything lower kebab-case, prefixed `ef-`: config declares only the
  project *suffix*; the full name `ef-<env>-<suffix>` is generated from the
  environment the entry sits under and becomes the workspace, the GCP
  project id, and the default repository name. A repository shared across
  environments is named explicitly with `repo:`.
- Module repositories generate `ef-lib-<name>`, published as registry
  module `<name>`.
- Derived names are derived, never repeated in config: service account
  `sa-<env>-tfc`, pool `ef-<env>-tfc`, provider `tfc-<env>`, TFC project
  `ef-<env>`, budget `ef-budget-<name>`, DNS zone name from the domain with
  dots replaced by dashes.
- Platform identifiers in code are the provider names: `google`, `tfe`,
  `github`. Not the product abbreviations — `gcp`, `tfc`, `gh` are retired.
  Product names survive only inside data values (`sa-<env>-tfc`,
  `tfc-<env>`, `ef-<env>-tfc`).
- Modules are named after their function, not their platform; single words,
  singular, matching the deliverable they package.

## YAML

- Config files are named by setup concern, not by platform:
  `organisation.yaml` (who we operate as — org domain, region, billing
  account display name, TFC and GitHub handles), `budgets.yaml` (budget
  alerts), `zones.yaml` (DNS zones and platform records), `environments.yaml`
  (a flat list, one entry per environment, each hosting `projects`), and
  `modules.yaml` (a flat list of Terraform module repositories outside any
  environment).
- Each file has one top-level key matching the filename; `locals.tf` merges
  the files into `config` and exposes the namespaces.
- **A project is one entry**: declaring `environments[].projects[]` mints
  the GitHub repository, the TFC workspace (in the environment's TFC
  project `ef-<env>`), and the GCP project directly under the organisation
  root. Example: `mgt` + suffix `devops` yields repo, workspace and GCP
  project `ef-mgt-devops`.
- **A module is one entry**: declaring `modules[]` mints the repository
  `ef-lib-<name>` and a private TFC registry module (module name `<name>`,
  published from the repository by git tag). It creates no workspace, no
  service account, and no GCP project.
- YAML files use **block style only** — no flow/JSON syntax (`{...}`
  mappings or `[...]` inline sequences). One entry per line keeps diffs
  reviewable.
- Values are **plain scalars — no quote marks** in `environments/`. A value
  that would need quoting is reworded instead (no `: ` inside strings — the
  repository description uses `-` for exactly this reason). `.schemas/` is
  exempt: JSON Schema regex patterns and prose descriptions legitimately
  carry quotes.
- Optional inputs with platform defaults are omitted from the YAML. Names
  are derived, never repeated: config carries suffixes only.
- `.schemas/environment/` — JSON Schema (draft-07, in YAML) mirroring the
  `environments/<env>/` filenames; every registry change lands in its
  schema in the same PR. Instances bind to them with a
  `yaml-language-server` modeline — one of the two permitted comment forms.

## Layout

- `infrastructure/` — all Terraform (the TFC working directory); purpose
  files; repo-local modules under `modules/<function>/`, each with
  `variables.tf`, `outputs.tf`, `versions.tf`, plus
  `data.tf`/`checks.tf`/`_<category>.tf` when owned. The root declares no
  outputs: the platform publishes none. No comments in any `.tf` file.
- `environments/<name>/` — YAML inputs, one directory per environment slot,
  split by concern, merged alphabetically in `locals.tf`. A new environment
  slot adds its directory and extends the `environment` variable validation.
- `scripts/` — bash for orchestration only (seed, adopt, deploy); never
  validation logic. `imports.tf` is transient — rendered by bootstrap,
  never committed. `inventory.yaml` is transient — deleted at close-out.
- `.schemas/environment/` — one schema per config filename.
- `docs/` — exactly three files: `DESIGN.md` (decisions and rationale),
  `STANDARDS.md` (binding rules, this file), `BOOTSTRAP.md` (the one-time
  bring-up procedure); `README.md` points here. New documentation extends
  these; it does not add a fourth.

## Review rules

- Steady state is code-only: console changes are read-only; any manual
  change is drift and must be adopted or reverted within one working day.
  The one sanctioned exception: installing the TFC GitHub App itself.
- Every change arrives as a PR; CI runs fmt/validate/plan; merge to `main`
  triggers the TFC run. The plan-only pass catches validation, precondition,
  and check failures before merge.
- Structural resources (projects, workspaces, zones) may only be created by
  TFC under the matching scope — enforced by org policies and IAM, not
  convention.
- Provisioning anything new is a data change here — never a new variable,
  and never a hardcoded singular resource.
- This document is the bible: future agents read it before touching
  structure, and update it in the same PR as any convention change.
- CODEOWNERS at `.github/CODEOWNERS` lives in each repository's own
  content (not terraform-managed) and names the review owner for every
  path. The landing zone repo's CODEOWNERS covers all paths.

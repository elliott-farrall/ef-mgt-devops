# Design

This is the design document for the EF platform: decisions and rationale,
maintained in the repository they describe and versioned by its git history.
The binding rules live in [standards.md](standards.md); the bring-up procedure
in [bootstrap.md](bootstrap.md). Read this file before proposing anything
structural.

## Principles

- **Everything is infrastructure as code.** After bootstrap, consoles are
  read-only; every change to the platform arrives as a PR to this repository.
- **Bootstrap is scripts + imports.** Numbered seed scripts create the
  chicken-and-egg resources (folders must exist before any workspace can
  manage them); `terraform import` then adopts everything into state. There is
  deliberately no permanent bootstrap codebase — the scripts are short-lived
  seeds, the inventory is transient (deleted at close-out), the code is the
  steady state.
- **One hierarchy, three mirrors.** GCP folders, Terraform Cloud projects, and
  repository namespaces mirror each other with predictable names
  (`ef-mgt/ef-hub/ef-app`). Structure is enforced by IAM and org policies, not
  convention.
- **Environments are data.** The same code serves every environment; the single
  `environment` input selects the YAML inputs, naming, labels, identity, and
  apply policy. New behaviour is expressed as derivation in `locals.tf`, never
  as a new variable.
- **Validation is Terraform-native.** `validation`, `precondition`, and `check`
  blocks fail bad input at plan time. Shell scripts only orchestrate — if a
  rule can be checked in HCL, it must be.
- **Modules start local.** `infrastructure/modules/` until code genuinely must
  cross repositories; then extract to `ef-lib-*` and publish by tag. Premature
  extraction is the failure mode this guards against.
- **Least privilege, derived.** One kind of identity: `sa-<env>-tfc` per
  environment, minted by the code from `environments` — every
  infrastructure-type entry gets the account, the `tfc-<env>` provider, and the
  core roles its function requires (project creation and editor at its own
  folder; impersonation and DNS admin at the landing project). The
  management environment is detected from the stack being applied and
  receives the platform roles on top — `ef-root` folder administration,
  organisation browse, billing user — so `sa-mgt-tfc` is both plane and
  platform identity, and no separate admin account exists to audit. All
  identities live in the landing project — the single project marked
  `default: true`, `ef-mgt-devops` — which also hosts every environment's
  pool and the DNS zone: one project fewer to audit. Identities are folder-scoped: admission is
  derived from the folder itself — every environment accepts workspaces
  named `ef-<env>-*` — and the grant binds the
  pool attribute `environment/<env>`, not any workspace subject. No
  workspace and no role is ever named in YAML. The bootstrap-only `sa-adm-bootstrap` is never declared
  and is deleted at close-out.
- **The management plane provisions the rest.** This repository manages itself
  *and* every other IaC project: its four YAML input files are registries
  split by setup concern — organisation facts, billing, domains,
  and environments. Landing a new `ef-*` project is a data change here, not new
  machinery.

## Environment model

Five slots partition the platform:

| Slot | Role | Why it exists |
|------|------|---------------|
| `mgt` | The platform itself | Operates org, folders, DNS, TFC; production-grade because everything else depends on it |
| `hub` | Shared services | Consumed by every environment, so it sits outside the ladder and gets a manual-confirm gate |
| `dev` | Experiments | Auto-apply: fast iteration where breakage is cheap |
| `pre` | Staging | Soaks after dev before anything real moves |
| `prd` | Production | Manual confirm only |

Isolation is structural: a project lives in exactly one environment folder,
each environment has its own service account and state, and cross-environment
reuse flows through hub services and lib modules — never shared projects.

## Self-management and extensibility

`ef-mgt-devops` is the root of the system: it creates the GCP folder
tree and projects, the TFC projects and *every*
workspace, the GitHub repositories and their branch protection, and the DNS
zones — including its own. The `environments/mgt/*.yaml` files are
therefore registries of flat entries: hierarchy is expressed by
`parent` pointers, not nesting — the data stays trivially readable and
the code stays free of unroll machinery. Everything iterates with a
`for_each` keyed by name. Nothing is special-cased: this repo appears in
its own `projects` entry under `mgt` exactly like a future
`ef-app-identity` under `dev`, `pre` and `prd` would.

Bringing up another project is then mechanical:

1. Add one `projects` entry of type `infrastructure` per deployment
   environment under that environment's entry — config carries only the
   suffix; the environment generates the full name `ef-<env>-<suffix>`;
   run policy optional; one repository shared across lanes is named
   explicitly with `repo:`. Supporting-code repositories are `module`
   entries under `lib`; plain repositories are `software`.
2. Merge the PR; the mgt run creates the repo, workspace, and project.
3. Scaffold the new repository to the same layout contract
   ([standards.md](standards.md)); its workspace already exists, so its first
   PR plans against real state from day one.
4. The new repo then manages *its own* resources. Cross-project
   references resolve **by name through provider data sources**
   (`google_folders`, `google_dns_managed_zone`, …) — this repository
   publishes no outputs and nothing couples to its internals. Names are the
   stable contract; IDs are looked up. A website repo's domain, for example,
   is one `google_dns_record_set` in the platform's apex zone plus a
   `data.google_dns_managed_zone` lookup — no new plumbing anywhere.

Plane boundaries stay hard: `ef-mgt-devops` provisions landing spots, but
workload resources live only in their own environment's projects, under their
own service account.

Policy is data too. Repository settings and branch protection live in
`locals.tf` as platform defaults — private, squash-only, PR-required, green-CI,
admin-enforced — and any registry entry may override them with an optional
`settings:` or `protection:` block. A new repo gets the house rules for free;
deviations are visible in the YAML where a reviewer can see them.

## Cost control

GCP budgets alert; they never cap — so the platform treats the two
mechanisms separately. Budget alerts are declared in `billing.budgets` (in `billing.yaml`):
a config suffix whose display name is generated as `ef-budget-<name>`, a monthly amount in GBP — the platform currency, hardcoded in the module,
not config — a list of threshold fractions
(0.5, 0.8, 1.0), and an optional `scope` naming a resolved ancestor
(`projects/…`, `folders/…`, `organizations/…) — omit it for an account-wide budget. The convention is
one account-wide budget plus one per plane as planes acquire projects.
Notifications go to billing-account recipients by default; a Pub/Sub
channel per budget is the steady-state upgrade.

The real guardrails against runaway spend are structural, not monetary:
the organisation policies (allowed regions, required labels), the
manual-confirm gates on mgt/hub/prd applies, and weekly drift checks
that catch surprise resources before they bill a second month.

## Platform roles

Each platform does exactly one job:

- **GitHub** — source of truth and CI validation. Holds *no* cloud apply
  credentials; a compromised repo cannot touch infrastructure. Repo settings
  and `main` branch protection are managed here like everything else, via the
  `github-repository` module (provider `integrations/github`) with a fine-grained token
  scoped to this repository only.
- **Terraform Cloud** — the single deployment engine. All applies run as TFC
  workspace identities; run policy (plan/apply gates) is per environment.
- **GCP** — the workload, plus the hierarchy the platform manages. Never
  reached by static keys: workload identity federation only.
- **Cloud DNS (GCP)** — DNS, natively. The platform owns the public zones;
  workload repos add records by name lookup. (Cloudflare remains the domain
  *registrar* — a billing relationship, not infrastructure.)

## Resource map

This section maps every resource the stack creates onto its source platform,
its configuration key, and its naming rule. Hierarchy is expressed by
parent pointers in data; identifiers are looked up by name at plan time.

### What GCP creates

All GCP resources are provisioned through Google provider modules and driven
from `environments/mgt/*.yaml`. Folders and projects appear on first apply;
billing and DNS also on first apply. Identity derives from the environment list.

| Resource | Module | Config source | Naming rule | Parent / scope |
|----------|--------|---------------|-------------|----------------|
| GCP folder | `google-folder` | `environments[].parent` | `ef-<name>` | org root (`folder_id = var.tree.root_parent`) or another folder (`parent`) |
| GCP project | `google-project` | `projects[]` | `ef-<env>-<suffix>` | folder (`folder_id`) + billing account (`data.google_billing_account.ef.billing_account`) |
| Service account | `google-service-account` | derived from infrastructure envs | `sa-<env>-tfc` | landing project (the default project) |
| Workload identity pool | `google-workload-identity-pool` | derived from infrastructure envs | `ef-<env>-tfc` | landing project |
| WIF provider | `google-workload-identity-provider` | derived from infrastructure envs | `tfc-<env>` | pool (see above) + OIDC issuer `https://<hostname>` |
| SA workloadIdentityUser binding | built into provider module | — | — | pool project number → `sa-<env>-tfc` email |
| IAM member (folder/project/org/billing) | `google-iam-member` | derived bindings | — | scope path (`folders/<id>`, `projects/<id>`, `organizations/<id>`, `billingAccounts/<id>`) |
| Billing budget | `google-billing-budget` | `billing.budgets[]` | display: `ef-budget-<name>` | billing account + optional scope filter |
| DNS managed zone | `google-dns-managed-zone` | `domain.yaml[].name` | `name` = auto-generated from domain (dots → dashes) | landing project |
| DNS record sets | built into dns-managed-zone module | `domain.yaml[].records[]` | — | zone (same module, keyed by name+type) |

Naming convention summary: environments carry suffix-only names (e.g. `devops`). Terraform generates full names for all GCP resources as `ef-<env>-<suffix>` (project IDs), `sa-<env>-tfc` (service accounts), `ef-<env>-tfc` (WIF pools). The billing account display resolves to `ef-billing` and budgets to `ef-budget-<name>` where `<name>` comes from config.

### What Terraform Cloud creates

TFC resources mirror the GCP hierarchy: one project per infrastructure-type
environment, one workspace per infrastructure project entry, and one registry
module per library-project entry.

| Resource | Module | Config source | Naming rule | Scope |
|----------|--------|---------------|-------------|-------|
| TFC project | `tfe-project` | derived from infrastructure envs | `ef-<env>` | organization-level |
| TFC workspace | `tfe-workspace` | derived from infrastructure projects | `ef-<env>-<suffix>` | tfe-project |
| Workspace branch protection | built into workspace module | derived | — | workspace (execution_mode = remote) |
| Workspace environment variables | built into workspace module | derived | `environment`, `WIF_PROVIDER`, `GOOGLE_IMPERSONATE_SERVICE_ACCOUNT` | workspace |
| Registry module | `tfe-registry-module` | `lib` entries under each environment | module name | private registry, VCS-linked repo |

Workspaces embed their own identity plumbing: `WIF_PROVIDER` points to the
GCP pool address and `GOOGLE_IMPERSONATE_SERVICE_ACCOUNT` names the SA that
the workspace assumes after OIDC exchange. No manual credential provisioning
is required.

### What GitHub creates

Every infrastructure-project entry produces a GitHub repository with standardised
branch protection: squash-only merge, auto-delete on merge, admin enforcement,
required PR reviews, and mandatory status checks.

| Resource | Module | Config source | Naming rule | Scope |
|----------|--------|---------------|-------------|-------|
| Repository | `github-repository` | union of all `projects[]` entries | `ef-<env>-<suffix>` | owner (`organisation.gh.owner`) |
| Branch protection | built into github-repository module | derived defaults, overridable per-entry | — | repo `main` branch |

Cross-environment repo sharing is possible: multiple lane entries can reference
a single repository via the `repo:` override on a project entry.

### How the platforms link together

The three links described in the integration table operate through exact names;
no identifier leaks out of one platform into another. The chain runs left-to-right:

```
config → terraform locals → module call → resource creation
```

The authentication chain (TFC → GCP) works like this:

1. A TFC workspace receives a pull request event (or a direct trigger).
2. TFC issues an OIDC token scoped to the workspace and environment.
3. That token hits the `ef-<env>-tfc` workload identity pool in GCP.
4. The provider `tfc-<env>` verifies the OIDC issuer and evaluates
   `assertion.workspace_name.startsWith("ef-<env>-")` — if the condition
   passes, the admitted principalSet becomes `principalSet://.../attribute.environment/<env>`.
5. The pool binding grants `roles/iam.workloadIdentityUser` on the
   `sa-<env>-tfc` service account to that principalSet.
6. The workspace already carries `WIF_PROVIDER` and
   `GOOGLE_IMPERSONATE_SERVICE_ACCOUNT` as environment variables, so the
   run automatically impersonates the SA and proceeds with GCP API calls.
7. The SA's IAM bindings (folder editor, project creator, etc.) control
   exactly what the workspace can create inside its scope.

The TFC → GitHub link uses the same model but in reverse: the `github` provider
uses a user-scoped token stored as a TFC sensitive variable, scoped to manage
only this repository. The TFC GitHub App installed once connects webhooks
(status checks on PRs, push-triggered runs on `main`).

No resource ever publishes its ID to another platform. Folder names become
project IDs become workspace names become repository names. One stable name
traverses three platforms, resolved at plan time by provider data sources.

### Creation timeline

| Phase | What happens | Who triggers it |
|-------|--------------|------------------|
| Bootstrap Step 1–2 | Shell scripts seed folders, enable APIs, link billing; inventory YAML records pending imports | Operator machine |
| Bootstrap Step 3 | `terraform import` adopts every seed-created resource into state using module addresses from the import table | Operator machine |
| First apply | All remaining resources (workspaces, SAs, pools, providers, bindings, budgets, DNS zones, repos, branch protection) are created in parallel | mgt environment run |
| Subsequent changes | Data change in YAML → PR → CI validate/fmt → merge → TFC plan → confirm (per run policy) → apply | Any contributor |
| New project bring-up | Add `projects` entry → merge → mgt creates repo/workspace/project → scaffold new repo → self-manages own resources | Project lead |

Bootstrap resources (folders, billing account link) exist before any Terraform
state; `terraform import` stitches them in. Everything else is pure code.

The platforms are joined by exactly three links — nothing authenticates to
anything else, anywhere:

| Link | Mechanism | Credential |
|------|-----------|------------|
| GitHub ↔ TFC | TFC GitHub App: webhook runs on `main`, status checks on PRs | App installed once as a prerequisite; workspace links managed by Terraform via the installation ID |
| TFC → GCP | Workload identity federation: run exchanges its OIDC token at the `ef-<env>-tfc` pool; provider `tfc-<env>` (folder-derived CEL condition; admitted tokens are stamped `attribute.environment/<env>`) binds the environment's principalSet to its service account via `workloadIdentityUser`; runs automatically receive `WIF_PROVIDER` and `GOOGLE_IMPERSONATE_SERVICE_ACCOUNT` as workspace environment variables | `sa-<env>-tfc`; `sa-mgt-tfc` doubles as platform administration |
| TFC → GitHub | GitHub provider (`integrations/github`) manages repo settings and branch protection | Fine-grained token as sensitive variable, this repository only |

A fourth link exists only during bootstrap: the operator's machine authenticates
to TFC with a user token for `init`/`import` (Step 3) and it is revoked at
Step 5. In steady state, no human credential touches the deployment path.

## Deployment workflow

    developer → GitHub PR → CI checks → merge to main
              → TFC run (plan) → confirm (per run policy) → apply

Pull requests run fmt, validate (no backend), and a plan-only pass so every
validation, precondition, and check block executes before merge. A merge to
`main` starts a TFC run; whether it auto-applies is the environment's run
policy, not the code's choice. Weekly drift checks compare state to reality;
findings open a run and an issue — adoption or revert within one working day,
never console-fix.

## Repository layout

One repository (`ef-mgt-devops`) holds the entire management plane: code,
environment inputs, bootstrap scripts, and this documentation. Splitting them
would let the runbook and the code drift apart — the import list must match
the module addresses, so they live and change together. The layout contract for
all future `ef-*` repositories is defined in [standards.md](standards.md).

## Where things live

| Question | Document |
|----------|----------|
| Why is it shaped this way? | `docs/design.md` (this file) |
| What are the binding rules? | `docs/standards.md` |
| How do we bring it up? | `docs/bootstrap.md` |
| What changed and when? | git history of these three files |

# Design

This is the design document for the EF platform: decisions and rationale,
maintained in the repository they describe and versioned by its git history.
Binding rules live in [STANDARDS.md](STANDARDS.md). Read this file before
proposing anything structural.

## Principles

- **Everything is infrastructure as code.** After bootstrap, consoles are read-only; every change arrives as a PR. Manual changes are drift and must be adopted or reverted within one working day.
- **Bootstrap is scripts + imports.** Seed scripts create chicken-and-egg resources (`terraform import` then adopts them). There is no permanent bootstrap codebase — scripts are short-lived seeds, the code is steady state.
- **One name, three mirrors.** Names — project ID, workspace name, repository name — mirror each other with predictable names; one folder per environment mirrors them at the top. Structure is enforced by folders, IAM, and org policies, not convention.
- **Environments are data.** The same code serves every environment. The single `environment` input selects YAML inputs, naming, labels, identity, and apply policy. New behaviour is derivation in `locals.tf`, never a new variable.
- **Validation is Terraform-native.** `validation`, `precondition`, and `check` blocks fail bad input at plan time. Shell scripts only orchestrate — if a rule can be checked in HCL, it must be.
- **Modules start local.** `infrastructure/modules/` until code genuinely must cross repositories. Premature extraction is the failure mode this guards against.
- **Least privilege, derived.** One identity kind: `sa-<env>-tfc` per environment, minted from config. All identities live in the landing project, which also hosts every pool and the DNS zone. No workspace and no role is ever named in YAML.
- **Management plane provisions everything.** This repo manages itself and every future `ef-*` project. Landing a new project is a data change here, not new machinery.
- **Names traverse platforms.** Folder name → project ID → workspace name → repository name. One stable name resolved at plan time by provider data sources. No ID leaks between platforms.

## Environments

Five flat infrastructure environments, each directly under the organisation
root — no folder tree, no type field. Each environment owns a TFC project,
service account, WIF pool, and the workspaces of its projects. Repositories
without infrastructure (registry modules, utilities) live in
`projects.yaml` as a project of type `lib` with no environments: a
library entry mints a
repository, `ef-lib-<name>`, published to the TFC private registry.

| Slot | Role | Run policy | Why it exists |
|------|------|------------|---------------|
| `mgt` | Platform management | Operates org, DNS, TFC; production-grade because everything else depends on it |
| `hub` | Shared services | Consumed by every environment, so it sits outside the ladder |
| `dev` | Experiments | Fast iteration where breakage is cheap |
| `pre` | Staging | Soaks after dev before anything real moves |
| `prd` | Production | Guarded by review and predictive-plan gates rather than apply-time confirmation |

Isolation is structural: a project lives in exactly one environment, each
environment has its own service account and state, and cross-environment
reuse flows through hub services and registry modules.

### Naming convention

Config carries suffix-only names. Terraform generates full names as `ef-<env>-<suffix>`.

| Entity | Config example | Generated name | Scope |
|--------|---------------|----------------|-------|
| Environment | `name: devops` | `ef-mgt-devops` (project) / `ef-mgt-devops` (workspace) / `ef-mgt-devops` (repo) | Entire platform |
| Service account | derived | `sa-dev-tfc` | Landing project |
| WIF pool | derived | `ef-dev-tfc` | Landing project |
| TFC project | derived | `ef-dev` | TFC organisation |
| Billing budget display | `budgets[].name: total` | `ef-budget-total` | GCP billing account |
| DNS zone name | `zones.yaml[].name: elliott-farrall.phd` | `elliott-farrall-phd` | Landing project |
| Application | `projects[].type: app`, `environments: [dev, pre, prd]` | `ef-app-web` (repo) / `ef-dev-web` … (deployments) | Owner namespace / lanes |
| Module | `modules[].name: registry` | `ef-lib-registry` (repo) / `registry` (registry module) | Owner namespace / TFC private registry |

### Cross-environment access

Reuse flows through two mechanisms:

1. **Hub services** consumed by all lanes. Hub projects sit outside the development ladder.
2. **Library modules** published to the private TFC registry, declared in
   type-`lib` projects and consumed by any lane via `tfe_registry_module`.

No shared projects exist.

## Platforms

Code is organised by function, not by platform. Five repo-local modules,
each packaging the resources of one deliverable and driven by `for_each`
from environment configuration:

| Module | Keyed by | Packages |
|--------|----------|----------|
| `environment` | environment | TFC project, service account, WIF pool + provider, SA bindings |
| `project` | project | GitHub repository + protection, GCP project + APIs, TFC workspace + variables |
| `module` | repository | GitHub repository + protection, private TFC registry module |
| `zone` | zone | DNS managed zone + record sets |
| `budget` | budget | Billing budget alert |

### Google Cloud

GCP hosts the workloads and federation plumbing. Identity admission derives from the workspace name prefix against its environment's pool. All GCP resources are created on the first Terraform apply after bootstrap imports existing state.

#### Folders

One folder per environment, named `ef-<env>`. Lane environments may
declare a cosmetic `parent` group folder — `app` collects `dev`, `pre`,
and `prd` — hanging their folders under `ef-<parent>`. Every project is created inside its environment's folder,
which gives each environment identity a bounded creation scope: its
`projectCreator` and `editor` roles hang off its own folder, so an
environment can never mint projects outside it.

#### Projects

One GCP project deployed. The management plane runs inside its own project; the other environments exist as workspaces but no compute yet.

| Project ID | Billing | Description | Default |
|------------|---------|-------------|---------|
| `ef-mgt-devops` | `ef-billing` | DevOps Management | Yes |

Hub, dev, pre, and prd exist as environments and TFC projects but hold no
GCP projects today. Deployments appear when projects declare them in
`projects.yaml`.

#### Workload identity federation

One OIDC-based auth chain per environment. Five SAs, five pools, five providers — all hosted in `ef-mgt-devops`.

```
TFC run → OIDC token → ef-<env>-tfc pool (GCP)
         ├─ check: workspace_name.startsWith("ef-<env>-")
         └─ attribute.environment = "<env>"

Pool principalSet → roles/iam.workloadIdentityUser → sa-<env>-tfc
                                                    │
                                                    └→ WORKSPACE env vars:
                                                        - TFC_GCP_PROVIDER_AUTH
                                                        - TFC_GCP_WORKLOAD_IDENTITY_PROVIDER
                                                        - TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL
```

| Pool Name | Provider Name | SA Email Pattern | Purpose |
|-----------|---------------|------------------|---------|
| `ef-mgt-tfc` | `tfc-mgt` | `sa-mgt-tfc@[PROJECT].iam.gserviceaccount.com` | Management plane identity |
| `ef-hub-tfc` | `tfc-hub` | `sa-hub-tfc@[PROJECT].iam.gserviceaccount.com` | Shared services identity |
| `ef-dev-tfc` | `tfc-dev` | `sa-dev-tfc@[PROJECT].iam.gserviceaccount.com` | Experiment workspace identity |
| `ef-pre-tfc` | `tfc-pre` | `sa-pre-tfc@[PROJECT].iam.gserviceaccount.com` | Staging workspace identity |
| `ef-prd-tfc` | `tfc-prd` | `sa-prd-tfc@[PROJECT].iam.gserviceaccount.com` | Production workspace identity |

The manager receives extra IAM bindings beyond the standard set: organisation admin, project owner on `ef-mgt-devops`, billing user.

#### IAM bindings

IAM member resources across four scope types:

| Scope | Target | Bindings | Count |
|-------|--------|----------|-------|
| Project creator + editor | Own environment's future projects | All five SAs | 10 |
| Service account impersonation | `ef-mgt-devops` (landing) | All five SAs | 5 |
| DNS admin | `ef-mgt-devops` (landing) | All five SAs | 5 |
| Platform roles | `ef-mgt-devops`, organisation root, billing account | mgt-sa only | 3 |

All bindings resolve targets by name using provider data sources. No hardcoded IDs.

#### Billing budgets

One account-wide budget alerting on the GCP billing account.

| Display Name | Amount | Thresholds | Scope | Notification |
|--------------|--------|------------|-------|--------------|
| `ef-budget-total` | £30 GBP | 50%, 80%, 100% | Account-wide (no filter) | Billing account recipients |

Budget alerts trigger notifications but never cap spending — structural guardrails (org policies, manual-confirm gates, weekly drift checks) handle runaway spend.

#### DNS

DNS for the apex lives in Cloudflare, managed as code by this repository: the `record` module creates the Proton mail records (two MX, SPF, verification, DMARC, three DKIM CNAMEs) through the Cloudflare provider. Future projects own their subdomains end to end — a Cloud DNS subzone on the GCP side plus the delegating NS records in the Cloudflare apex — so a new project subdomain never touches this repository.

| Property | Value |
|----------|-------|
| Zone name | `elliott-farrall-phd` |
| DNS name | `elliott-farrall.phd.` |
| Project | `ef-mgt-devops` |

Record sets:

| Record | Type | TTL | Values |
|--------|------|-----|--------|
| `elliott-farrall.phd` | MX | 300 | 10 mail.protonmail.ch, 20 mailsec.protonmail.ch |
| `elliott-farrall.phd` | TXT | 300 | v=spf1 include:_spf.protonmail.ch ~all; protonmail-verification=ea77d... |
| `_dmarc.elliott-farrall.phd` | TXT | 300 | v=DMARC1; p=quarantine |
| `protonmail._domainkey.elliott-farrall.phd` | CNAME | 300 | protonmail.domainkey.*proton.ch |
| `protonmail2._domainkey.elliott-farrall.phd` | CNAME | 300 | protonmail2.domainkey.*proton.ch |
| `protonmail3._domainkey.elliott-farrall.phd` | CNAME | 300 | protonmail3.domainkey.*proton.ch |

Workload repos add records by looking up the zone by name (`data.google_dns_managed_zone`).

### Terraform Cloud

TFC is the single deployment engine. All applies run under workspace identities with remote execution mode. Workspaces VCS-link to their GitHub repositories via the TFC GitHub App installation.

#### TFC Projects

Five logical groupings containing workspaces. One per environment.

| Project Name | Environment | Purpose |
|--------------|-------------|---------|
| `ef-mgt` | `mgt` | Platform management — runs `feature/initialise`, manages entire stack |
| `ef-hub` | `hub` | Shared services — consumed by every lane; manual-confirm gate |
| `ef-dev` | `dev` | Experiment workspace |
| `ef-pre` | `pre` | Staging workspace — manual-confirm before prod |
| `ef-prd` | `prd` | Production workspace — manual-confirm gate |

#### TFC Workspaces

One workspace deployed today. Additional workspaces appear automatically when projects declare deployments in `projects.yaml`.

| Workspace Name | TFC Project | Repository | Execution Mode | Auto-apply | Linked Variables |
|---------------|-------------|------------|----------------|------------|------------------|
| `ef-mgt-devops` | `ef-mgt` | `ef-mgt-devops` | Remote | Yes | `environment=mgt`, `TFC_GCP_PROVIDER_AUTH=true`, `TFC_GCP_WORKLOAD_IDENTITY_PROVIDER`, `TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL` |

Workspace variables embed identity plumbing. Three variables per workspace — declared category, assigned purpose, runtime value populated at apply.

| Variable | Category | Purpose | Runtime Value |
|----------|----------|---------|---------------|
| `environment` | terraform | Declares deployment slot | `mgt` |
| `TFC_GCP_PROVIDER_AUTH` | env | Enables HCP Terraform dynamic credentials for the Google provider | `true` |
| `TFC_GCP_WORKLOAD_IDENTITY_PROVIDER` | env | Full WIF provider path for OIDC exchange | `projects/<landing>/locations/global/workloadIdentityPools/ef-mgt-tfc/providers/tfc-mgt` |
| `TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL` | env | SA to impersonate after token exchange | `sa-mgt-tfc@[PROJECT].iam.gserviceaccount.com` |

#### Registry Modules

Zero registry modules currently deployed. They are created when
type-`lib` projects are added — publisher-provided module names,
version-tagged, pinned by consumers.

### GitHub

GitHub is source of truth and CI validation. It holds no cloud apply credentials. A compromised repository cannot touch infrastructure.

#### Repositories

One repository deployed today. Additional repositories appear automatically when `projects.yaml` or `modules.yaml` gain entries.

| Repository | Namespace | Visibility | Branch Protection | Linked Workspace |
|-----------|-----------|------------|-------------------|------------------|
| `ef-mgt-devops` | `elliott-farrall` | Private | See table below | `ef-mgt-devops` |

Cross-environment repo sharing: multiple environment slots can share a single repository by setting `repo:` on their project entry. One repo = one set of branch protection; lanes sharing it inherit the same defaults unless explicitly overridden. Currently no sharing configured.

#### Branch Protection Rules

Standardised across every repository with optional per-repo overrides.

Two repository rulesets govern `main` (see STANDARDS.md):

| Ruleset | Contents | Bypass |
|---------|----------|--------|
| Enforcement | 4 CI checks + TFC Predictive plan required, strict, linear history, no force-push, no deletion | None — admins included |
| Review | 1 approving review, resolved conversations, stale reviews dismissed on push, squash only | Repository admin, `pull_request` mode only — bypassing never permits direct pushes |

Required status checks: `["ci/checks"]` (configured per-repo via CI pipelines).

#### CI Integration

The TFC GitHub App connects two systems:

| Event | Action | Platform |
|-------|--------|----------|
| Pull request push | CI runs status checks (format + validate + plan-only) | GitHub Actions |
| Merge to `main` | TFC triggers run (plan → confirm → apply) | TFC |

GitHub Actions holds no cloud credentials — CI validates code without backend connectivity. Actual apply runs execute in TFC under workspace identities.

## Codebase

### Repository Structure

One repository (`ef-mgt-devops`) holds the entire management plane: code, environment inputs, bootstrap scripts, and documentation. Splitting would let the runbook and the code drift apart.

```
├── .github/workflows/       # CI: branch-name, schema, fmt/validate
├── .schemas/environment/    # JSON Schema per environment config file
├── scripts/
│   └── bootstrap.sh         # Bash orchestration (seed, import, deploy)
├── docs/                    # Two-file convention
│   ├── DESIGN.md            # Decisions and rationale (this file)
│   └── STANDARDS.md         # Binding rules (naming, layout, review)
├── environments/            # YAML inputs, split by concern
│   └── mgt/                 # Management environment config
│       ├── organisation.yaml # Org facts: domain, region, GH owner, TFC hostname
│       ├── budgets.yaml      # Budget alerts
│       ├── zones.yaml        # DNS zones + record sets
│       ├── environments.yaml # Deployment lanes
│       ├── projects.yaml     # Repositories, deployments, libraries
│       └── records.yaml      # Cloudflare apex zone records
├── infrastructure/          # Terraform working directory
│   ├── locals.tf            # All derivation from config
│   ├── main.tf              # Module calls + depends_on
│   ├── providers.tf         # Provider configurations
│   ├── data.tf              # Data sources (shared lookups)
│   ├── checks.tf            # Validation checks (cross-registry integrity)
│   └── modules/             # Repo-local Terraform modules, by function
│       ├── environment      # Folder + TFC project + identity + WIF + bindings
│       ├── group            # Cosmetic group folder
│       ├── repository       # GitHub repository + rulesets
│       ├── project          # Workspace + GCP project
│       ├── module           # Private registry module
│       ├── record           # Cloudflare DNS record
│       └── budget           # Billing budget alert
├── README.md              # Entry point
└── .gitignore
```

All files follow conventions defined in [STANDARDS.md](STANDARDS.md): no comments in code or YAML (only shebangs and `yaml-language-server` modelines), block-style YAML only, plain scalars where possible, module outputs mechanical (one per resource, resource-type named).

### Deployment Workflow

```
developer → GitHub PR → CI validate → merge to main
                      → TFC plan → confirm (per run policy) → apply
```

Pull requests trigger CI that runs format checks, schema validation, and Terraform validate (no backend). The plan-only pass catches validation/precondition/check block failures before merge. A merge to `main` starts a TFC run; whether it auto-applies follows the environment's run policy, not the code's choice.

Weekly drift checks compare state to reality. Findings open a run and issue — adoption or revert within one working day, never console-fix.

Console changes are drift. Any manual change must be adopted or reverted within one working day. The one exception: installing the TFC GitHub App itself (a prerequisite done once; its installation ID makes workspace linking pure Terraform thereafter).

### Import addresses

During bootstrap, seed-created resources are imported into state via module addresses matching the calling sites in `main.tf`. Addresses use module paths like `module.project["ef-mgt-devops"].google_project.this`, keyed by generated names, not hardcoded IDs.

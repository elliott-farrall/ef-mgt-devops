# Design

This is the design document for the EF platform: decisions and rationale,
maintained in the repository they describe and versioned by its git history.
Binding rules live in [standards.md](standards.md); the bring-up procedure
in [bootstrap.md](bootstrap.md). Read this file before proposing anything
structural.

## Principles

- **Everything is infrastructure as code.** After bootstrap, consoles are read-only; every change arrives as a PR. Manual changes are drift and must be adopted or reverted within one working day.
- **Bootstrap is scripts + imports.** Seed scripts create chicken-and-egg resources (`terraform import` then adopts them). There is no permanent bootstrap codebase — scripts are short-lived seeds, the code is steady state.
- **One hierarchy, three mirrors.** GCP folders, TFC projects, and GitHub namespaces mirror each other with predictable names. Structure is enforced by IAM and org policies, not convention.
- **Environments are data.** The same code serves every environment. The single `environment` input selects YAML inputs, naming, labels, identity, and apply policy. New behaviour is derivation in `locals.tf`, never a new variable.
- **Validation is Terraform-native.** `validation`, `precondition`, and `check` blocks fail bad input at plan time. Shell scripts only orchestrate — if a rule can be checked in HCL, it must be.
- **Modules start local.** `infrastructure/modules/` until code genuinely must cross repositories. Premature extraction is the failure mode this guards against.
- **Least privilege, derived.** One identity kind: `sa-<env>-tfc` per environment, minted from config. All identities live in the landing project, which also hosts every pool and the DNS zone. No workspace and no role is ever named in YAML.
- **Management plane provisions everything.** This repo manages itself and every future `ef-*` project. Landing a new project is a data change here, not new machinery.
- **Names traverse platforms.** Folder name → project ID → workspace name → repository name. One stable name resolved at plan time by provider data sources. No ID leaks between platforms.

## Environments

Five slots partition the platform. Infrastructure-type environments own a GCP folder, TFC project, service account, WIF pool, and workspaces. Library environments host registry modules only. Software environments get repositories but no identity plumbing.

| Slot | Type | Role | Run policy | Why it exists |
|------|------|------|------------|---------------|
| `mgt` | infrastructure | Platform management | manual confirm | Operates org, folders, DNS, TFC; production-grade because everything else depends on it |
| `hub` | infrastructure | Shared services | manual confirm | Consumed by every environment, so it sits outside the ladder |
| `dev` | infrastructure | Experiments | auto-apply | Fast iteration where breakage is cheap |
| `pre` | infrastructure | Staging | manual confirm | Soaks after dev before anything real moves |
| `prd` | infrastructure | Production | manual confirm | Safety gates on all applies |

Isolation is structural: a project lives in exactly one environment folder, each environment has its own service account and state, and cross-environment reuse flows through hub services and library modules.

### Naming convention

Config carries suffix-only names. Terraform generates full names as `ef-<env>-<suffix>`.

| Entity | Config example | Generated name | Scope |
|--------|---------------|----------------|-------|
| Environment | `name: devops` | `ef-mgt-devops` (project) / `ef-mgt-devops` (workspace) / `ef-mgt-devops` (repo) | Entire platform |
| Service account | derived | `sa-dev-tfc` | Landing project |
| WIF pool | derived | `ef-dev-tfc` | Landing project |
| TFC project | derived | `ef-dev` | TFC organisation |
| Billing budget display | `billing.budgets[].name: total` | `ef-budget-total` | GCP billing account |
| DNS zone name | `domain.yaml[].name: elliott-farrall.phd` | `elliott-farrall-phd` | Landing project |
| Cross-env repo share | `projects[].repo: shared-repo` | `ef-shared-repo` (created once) | Owner namespace |

### Cross-environment access

Reuse flows through two mechanisms:

1. **Hub services** consumed by all lanes. Hub projects sit outside the development ladder.
2. **Library modules** published to the private TFC registry, consumed by any lane via `tfe_registry_module`.

No shared projects exist.

## Platforms

Each platform does exactly one job. Resources are created by Terraform modules driven from environment configuration.

### Google Cloud

GCP hosts the workload hierarchy and federation plumbing. Identity is folder-scoped: admission derives from the folder itself. All GCP resources are created on the first Terraform apply after bootstrap imports existing state.

#### Folders

Seven hierarchical containers grouping projects. Bootstrap scripts create them; Terraform adopts them into state.

| Folder | Parent | Notes |
|--------|--------|-------|
| `ef-root` | Organisation root | Container for management-plane environments |
| `ef-mgt` | `ef-root` | Management plane — operates org, folders, DNS, TFC |
| `ef-hub` | `ef-root` | Shared services — consumed by every lane |
| `ef-app` | `ef-root` | Application tier — child environments deploy inside this folder |
| `ef-dev` | `ef-app` | Experiment space — fast iteration |
| `ef-pre` | `ef-app` | Staging environment |
| `ef-prd` | `ef-app` | Production environment |

All folders have `prevent_destroy` enabled.

#### Projects

One GCP project deployed. The management plane runs inside its own project; lane environments exist as folders and workspaces but no compute yet.

| Project ID | Folder | Billing | Description | Default |
|------------|--------|---------|-------------|---------|
| `ef-mgt-devops` | `ef-mgt` | `ef-billing` | DevOps Management | Yes |

Hub, dev, pre, and prd folders exist as organisational containers but hold no projects today. Projects appear when infrastructure-type entries gain `projects[]` definitions.

#### Workload identity federation

One OIDC-based auth chain per infrastructure-type environment. Five SAs, five pools, five providers — all hosted in `ef-mgt-devops`.

```
TFC run → OIDC token → ef-<env>-tfc pool (GCP)
         ├─ check: workspace_name.startsWith("ef-<env>-")
         └─ attribute.environment = "<env>"

Pool principalSet → roles/iam.workloadIdentityUser → sa-<env>-tfc
                                                    │
                                                    └→ WORKSPACE env vars:
                                                        - WIF_PROVIDER
                                                        - GOOGLE_IMPERSONATE_SERVICE_ACCOUNT
```

| Pool Name | Provider Name | SA Email Pattern | Purpose |
|-----------|---------------|------------------|---------|
| `ef-mgt-tfc` | `tfc-mgt` | `sa-mgt-tfc@[PROJECT].iam.gserviceaccount.com` | Management plane identity |
| `ef-hub-tfc` | `tfc-hub` | `sa-hub-tfc@[PROJECT].iam.gserviceaccount.com` | Shared services identity |
| `ef-dev-tfc` | `tfc-dev` | `sa-dev-tfc@[PROJECT].iam.gserviceaccount.com` | Experiment workspace identity |
| `ef-pre-tfc` | `tfc-pre` | `sa-pre-tfc@[PROJECT].iam.gserviceaccount.com` | Staging workspace identity |
| `ef-prd-tfc` | `tfc-prd` | `sa-prd-tfc@[PROJECT].iam.gserviceaccount.com` | Production workspace identity |

The manager receives extra IAM bindings beyond the standard set: folder admin over `ef-root`, project creator on `ef-mgt-devops`, organisation browser, and billing user.

#### IAM bindings

Twenty-four IAM member resources distributed across four scope types:

| Scope type | Target | Bindings | Count |
|------------|--------|----------|-------|
| Folder/project editor | Each infra folder + its project | mgt, hub, dev, pre, prd | 10 |
| Service account impersonation | `ef-mgt-devops` (landing) | All five infra SAs | 5 |
| DNS admin | `ef-mgt-devops` (landing) | All five infra SAs | 5 |
| Platform roles | `ef-root`, `ef-mgt-devops`, organisation root, billing account | mgt-sa only | 4 |

All bindings resolve targets by name using provider data sources. No hardcoded IDs.

#### Billing budgets

One account-wide budget alerting on the GCP billing account.

| Display Name | Amount | Thresholds | Scope | Notification |
|--------------|--------|------------|-------|--------------|
| `ef-budget-total` | £30 GBP | 50%, 80%, 100% | Account-wide (no filter) | Billing account recipients |

Budget alerts trigger notifications but never cap spending — structural guardrails (org policies, manual-confirm gates, weekly drift checks) handle runaway spend.

#### DNS

DNS resolution uses GCP Cloud DNS. Managed zone and six record sets hosted in `ef-mgt-devops`. (Cloudflare remains the registrar — billing relationship only.)

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

Five logical groupings containing workspaces. One per infrastructure-type environment.

| Project Name | Environment | Purpose |
|--------------|-------------|---------|
| `ef-mgt` | `mgt` | Platform management — runs `feature/initialise`, manages entire stack |
| `ef-hub` | `hub` | Shared services — consumed by every lane; manual-confirm gate |
| `ef-dev` | `dev` | Experiment workspace — auto-apply |
| `ef-pre` | `pre` | Staging workspace — manual-confirm before prod |
| `ef-prd` | `prd` | Production workspace — manual-confirm gate |

#### TFC Workspaces

One workspace deployed today. Additional workspaces appear automatically when infrastructure environments gain `projects[]` definitions.

| Workspace Name | TFC Project | Repository | Execution Mode | Auto-apply | Linked Variables |
|---------------|-------------|------------|----------------|------------|------------------|
| `ef-mgt-devops` | `ef-mgt` | `ef-mgt-devops` | Remote | No (manual confirm) | `environment=mgt`, `WIF_PROVIDER`, `GOOGLE_IMPERSONATE_SERVICE_ACCOUNT` |

Workspace variables embed identity plumbing. Three variables per workspace — declared category, assigned purpose, runtime value populated at apply.

| Variable | Category | Purpose | Runtime Value |
|----------|----------|---------|---------------|
| `environment` | terraform | Declares deployment slot | `mgt` |
| `WIF_PROVIDER` | env | GCP pool address for OIDC exchange | `projects/<landing>/locations/global/workloadIdentityPools/ef-mgt-tfc` |
| `GOOGLE_IMPERSONATE_SERVICE_ACCOUNT` | env | SA to impersonate after token exchange | `sa-mgt-tfc@[PROJECT].iam.gserviceaccount.com` |

#### Registry Modules

Zero registry modules currently deployed. They are created when infrastructure environments define `lib` entries — publisher-provided module names, version-tagged, pinned by consumers.

### GitHub

GitHub is source of truth and CI validation. It holds no cloud apply credentials. A compromised repository cannot touch infrastructure.

#### Repositories

One repository deployed today. Additional repositories appear automatically when infrastructure environments gain `projects[]` definitions.

| Repository | Namespace | Visibility | Branch Protection | Linked Workspace |
|-----------|-----------|------------|-------------------|------------------|
| `ef-mgt-devops` | `elliott-farrall` | Private | See table below | `ef-mgt-devops` |

Cross-environment repo sharing: multiple environment slots can share a single repository by setting `repo:` on their project entry. One repo = one set of branch protection; lanes sharing it inherit the same defaults unless explicitly overridden. Currently no sharing configured.

#### Branch Protection Rules

Standardised across every repository with optional per-repo overrides.

| Rule | Value | Overrideable |
|------|-------|--------------|
| Required approving reviews | 1 | Yes |
| Dismiss stale reviews on new commits | true | Yes |
| Require conversation resolution before merge | true | Yes |
| Strict status checks require upstream testing | true | Yes |
| Allowed merge methods | Squash only | No |
| Delete head branches on merge | true | Yes |

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
├── bootstrap/               # Bash orchestration (seed, import, cleanup)
│   ├── 01-google.sh         # Create folders, enable APIs, link billing
│   ├── 02-tfe.sh            # Create projects, variables, workspaces
│   ├── 03-import.sh         # Adopt seed-created resources into state
│   └── 04-cleanup.sh        # Delete inventory, bootstrap SA
├── docs/                    # Three-file convention
│   ├── design.md            # Decisions and rationale (this file)
│   ├── standards.md         # Binding rules (naming, layout, review)
│   └── bootstrap.md         # Bring-up procedure + import table
├── environments/            # YAML inputs, split by concern
│   └── mgt/                 # Management environment config
│       ├── organisation.yaml # Org facts: domain, region, GH owner, TFC hostname
│       ├── billing.yaml      # Billing account + budgets
│       ├── domain.yaml       # Domain zones + DNS records
│       └── environments.yaml # Environment list + projects + lib modules
├── infrastructure/          # Terraform working directory
│   ├── locals.tf            # All derivation from config
│   ├── main.tf              # Module calls + depends_on
│   ├── providers.tf         # Provider configurations
│   ├── data.tf              # Data sources (shared lookups)
│   ├── checks.tf            # Validation checks (cross-registry integrity)
│   └── modules/             # Repo-local Terraform modules
│       ├── google-folder           # Folder hierarchy
│       ├── google-project          # GCP projects
│       ├── google-service-account  # IAM service accounts
│       ├── google-billing-budget   # Budget alerts
│       ├── google-dns-managed-zone # DNS zones + record sets
│       ├── google-iam-member       # IAM bindings (folder/project/org/billing)
│       ├── google-workload-identity-pool     # WIF pools
│       ├── google-workload-identity-provider # WIF providers + SA binding
│       ├── tfe-project             # TFC projects
│       ├── tfe-workspace           # TFC workspaces + settings + variables
│       ├── tfe-registry-module     # Private registry modules
│       └── github-repository       # Repos + branch protection
├── README.md              # Entry point
└── .gitignore
```

All files follow conventions defined in [standards.md](standards.md): no comments in code or YAML (only shebangs and `yaml-language-server` modelines), block-style YAML only, plain scalars where possible, module outputs mechanical (one per resource, resource-type named).

### Deployment Workflow

```
developer → GitHub PR → CI validate → merge to main
                      → TFC plan → confirm (per run policy) → apply
```

Pull requests trigger CI that runs format checks, schema validation, and Terraform validate (no backend). The plan-only pass catches validation/precondition/check block failures before merge. A merge to `main` starts a TFC run; whether it auto-applies follows the environment's run policy, not the code's choice.

Weekly drift checks compare state to reality. Findings open a run and issue — adoption or revert within one working day, never console-fix.

Console changes are drift. Any manual change must be adopted or reverted within one working day. The one exception: installing the TFC GitHub App itself (a prerequisite done once; its installation ID makes workspace linking pure Terraform thereafter).

### Import addresses

During bootstrap, seed-created resources are imported into state via module addresses matching the calling sites in `main.tf`. See [bootstrap.md](bootstrap.md) for the complete import table. Addresses use module paths like `module.google-project["ef-mgt-devops"].google_project.this`, keyed by generated names, not hardcoded IDs.

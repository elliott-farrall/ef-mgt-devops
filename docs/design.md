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
- **Least privilege.** One workload identity per scope, bound at the matching
  folder. The only org-level identity (`sa-adm-bootstrap`) is deleted at Step 6.
- **The management plane provisions the rest.** This repository manages itself
  *and* every other IaC project: its YAML inputs are registries — the GCP
  folder tree, TFC projects and workspaces, GitHub repositories, Cloudflare
  zones. Landing a new `ef-*` project is a data change here, not new
  machinery.

## Environment model

Five slots partition the platform:

| Slot | Role | Why it exists |
|------|------|---------------|
| `mgt` | The platform itself | Operates org, folders, TFC, Cloudflare; production-grade because everything else depends on it |
| `hub` | Shared services | Consumed by every environment, so it sits outside the ladder and gets a manual-confirm gate |
| `dev` | Experiments | Auto-apply: fast iteration where breakage is cheap |
| `pre` | Staging | Soaks after dev before anything real moves |
| `prd` | Production | Manual confirm only |

Isolation is structural: a project lives in exactly one environment folder,
each environment has its own service account and state, and cross-environment
reuse flows through hub services and lib modules — never shared projects.

## Self-management and extensibility

`ef-mgt-devops` is the root of the system: it creates the GCP folder tree
(folders with projects hanging off them, nested arbitrarily in the YAML), the
TFC projects and *every* workspace, the GitHub repositories and their branch
protection, and the DNS zones — including its own. The `environments/mgt/*.yaml`
files are therefore registries: `locals.tf` unrolls the folder tree into flat
keyed nodes (4 levels deep, with a check block refusing deeper), and
everything else is a `for_each` keyed by name. Nothing is special-cased: this
repo appears in its own `gh.repositories` and `tfc.workspaces` lists exactly
like a future `ef-app-identity` would.

Bringing up another project is then mechanical:

1. Add entries to the registries here — `gh.repositories`, a workspace
   nested under its `tfc.projects` entry (run policy travels with it), and
   `gcp.folders` (add the project to its folder's `projects` list) if it
   needs a new project.
2. Merge the PR; the mgt run creates the repo, workspace, and project.
3. Scaffold the new repository to the same layout contract
   ([standards.md](standards.md)); its workspace already exists, so its first
   PR plans against real state from day one.
4. The new repo then manages *its own* resources. Cross-project reads go
   through `terraform_remote_state`, never through this repository's state.

Plane boundaries stay hard: `ef-mgt-devops` provisions landing spots, but
workload resources live only in their own environment's projects, under their
own service account.

Policy is data too. Repository settings and branch protection live in
`locals.tf` as platform defaults — private, squash-only, PR-required, green-CI,
admin-enforced — and any registry entry may override them with an optional
`settings:` or `protection:` block. A new repo gets the house rules for free;
deviations are visible in the YAML where a reviewer can see them.

## Platform roles

Each platform does exactly one job:

- **GitHub** — source of truth and CI validation. Holds *no* cloud apply
  credentials; a compromised repo cannot touch infrastructure. Repo settings
  and `main` branch protection are managed here like everything else, via the
  `gh` module (provider `integrations/github`) with a fine-grained token
  scoped to this repository only.
- **Terraform Cloud** — the single deployment engine. All applies run as TFC
  workspace identities; run policy (plan/apply gates) is per environment.
- **GCP** — the workload, plus the hierarchy the platform manages. Never
  reached by static keys: workload identity federation only.
- **Cloudflare** — DNS and edge. At launch just the apex zone; subzones arrive
  with workloads and delegate to Cloud DNS where needed.

## Integration

The platforms are joined by exactly four links — nothing authenticates to
anything else, anywhere:

| Link | Mechanism | Credential |
|------|-----------|------------|
| GitHub ↔ TFC | TFC GitHub App: webhook runs on `main`, status checks on PRs | App installation; no cloud creds |
| TFC → GCP | Workload identity federation: run exchanges OIDC token | `sa-mgt-tfc`, bound at folder `ef-mgt` |
| TFC → Cloudflare | Cloudflare provider on the apex zone | Zone-scoped API token as sensitive variable |
| Cloudflare → GCP | NS delegation of future subzones to Cloud DNS | Zone records only (deferred) |

A fifth link exists only during bootstrap: the operator's machine authenticates
to TFC with a user token for `init`/`import` (Step 4) and it is revoked at
Step 6. In steady state, no human credential touches the deployment path.

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

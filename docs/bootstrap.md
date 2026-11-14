# Bootstrap Runbook

The one deliberate exception to code-only operation. Scripts create, Terraform
adopts, the plan proves. Rationale: [design.md](design.md) — Principles and
Integration.

## Prerequisites (assumed in place)

- Accounts exist: GCP organisation, GitHub (`elliott-farrall`), Terraform
  Cloud — with no further configuration.
- A GCP **billing account is set up and linked to the organisation** with a live
  payment method — projects cannot be created or attached to folders without
  it. (Billing → Billing account; confirm `EF_BILLING_ACCOUNT` matches.)
- The **TFC GitHub App is installed and approved** for the
  `elliott-farrall` GitHub account — the one console action, done once.
  Its name (`Terraform Cloud`) is configured as `tfc.github_app_installation`
  and resolved to the installation ID by `data.tfe_github_app_installation`;
  Terraform then links every workspace to its repository automatically.
- Domain `elliott-farrall.phd` registered (registrar: Cloudflare Registrar —
  a billing relationship, not infrastructure). DNS moves to Cloud DNS as
  Terraform-managed zones; the one-time cutover is pointing the registrar's
  nameservers at the zone's `ns1.googledomains.com` set after the first
  apply.
- Repository `ef-mgt-devops` exists and this scaffold is on `main`.
- Local tooling: `gcloud` authenticated, `terraform`, `jq`, `curl`, `git`.
- Environment variables (never committed): `EF_ORG_ID` (or `EF_ORG_DOMAIN`
  to resolve it), `EF_BILLING_ACCOUNT`, `TFC_TOKEN`, `GITHUB_TOKEN`.
- `bootstrap/inventory.yaml` present (values are appended by the scripts). It is
  **transient**: it exists to hand IDs from the seed scripts to the import, and
  `04-cleanup.sh` deletes it at close-out.

## Steps

| # | Step | Mode | Command | Outcome |
|---|------|------|---------|---------|
| 1 | Seed GCP | script | `bootstrap/01-gcp.sh` | Hierarchy + IAM skeleton |
| 2 | Seed Terraform Cloud | script | `bootstrap/02-tfc.sh` | Deployment plane exists |
| 3 | Adopt via import | local TF | `bootstrap/03-import.sh` | Seed state in code's home |
| 4 | Prove the loop | TFC | run a full plan → **No changes** (workspace VCS link applied by this run); then point the registrar's nameservers at the Cloud DNS zone | Code-only steady state begins |
| 5 | Close out | script + console | `bootstrap/04-cleanup.sh`, then manual checklist | Bootstrapped, closed, documented |

`bootstrap/run.sh` runs Steps 1–3. Step 4 is the PR itself; Step 5 closes out
with `bootstrap/04-cleanup.sh`.

## Script scope (to implement during bootstrap prep)

- `01-gcp.sh`: landing project `ef-mgt-devops` (provider operating
  context and identity hosting) + billing link + API enablement; service
  accounts and every IAM binding are declared in `gcp.iam` —
  `sa-adm-tfc` for platform administration, one `sa-<env>-tfc` per plane,
  each naming its hosting project — plus the bootstrap-only
  `sa-adm-bootstrap` that config never declares;
  workload identity pool + OIDC provider for TFC, hosted in
  `ef-mgt-devops` (the `ef-mgt-devops` workspace assumes `sa-adm-tfc`);
  organisation policies
  (required labels, prevent project deletion, allowed regions).
- `02-tfc.sh`: global variable set `ef-global` (org/billing IDs);
  workspace `ef-mgt-devops` in project `ef-mgt` (VCS link applied by the
      first apply);
  sensitive variables (`CLOUDFLARE_API_TOKEN`, `GITHUB_TOKEN`) created via
  API — values never pass through this repository.
- DNS zones (apex and future delegations) are pure Terraform — created on
  first apply, no seed script, no import.
- `03-import.sh`: extend the import list as the module resources above land.

## Import address list

Authoritative mapping from `03-import.sh`. Extend as module resources land.

| Terraform address | Source (inventory key) | Import ID format |
|---|---|---|
| `module.gcp-folders.google_folder.tree["ef-root"]` | `folder_ef-root` | `folders/<ID>` |
| `module.gcp-folders.google_folder.tree["ef-mgt"]` | `folder_ef-mgt` | `folders/<ID>` |
| `module.gcp-folders.google_folder.tree["ef-hub"]` | `folder_ef-hub` | `folders/<ID>` |
| `module.gcp-folders.google_folder.tree["ef-app"]` | `folder_ef-app` | `folders/<ID>` |
| `module.gcp-folders.google_folder.tree["ef-dev"]` | `folder_ef-dev` | `folders/<ID>` |
| `module.gcp-folders.google_folder.tree["ef-pre"]` | `folder_ef-pre` | `folders/<ID>` |
| `module.gcp-folders.google_folder.tree["ef-prd"]` | `folder_ef-prd` | `folders/<ID>` |
| `module.gcp-project["ef-mgt-devops"].google_project.this` | `landing_project` | `<project-number>` |
| `module.tfc-project["ef-mgt"].tfe_project.this` | `tfc_project_ef-mgt` | `prj-<ID>` |
| `module.tfc-project["ef-hub"].tfe_project.this` | `tfc_project_ef-hub` | `prj-<ID>` |
| `module.tfc-project["ef-app"].tfe_project.this` | `tfc_project_ef-app` | `prj-<ID>` |
| `module.tfc-workspace["ef-mgt-devops"].tfe_workspace.this` | `tfc_workspace` | `<ws-ID>` |
| `module.tfc-workspace["ef-mgt-devops"].tfe_workspace_settings.this` | `tfc_workspace` | `<ws-ID>` |
| `module.gh-repository["ef-mgt-devops"].github_repository.this` | `gh_repository` | `ef-mgt-devops` (repo slug) |
| `module.gcp-service-account["sa-<env>-tfc"].google_service_account.this` | `sa_<env>_tfc` | `projects/<project>/serviceAccounts/<email>` |
| `module.gcp-iam-binding[*].*` | created by first apply | IAM bindings are additive; no import required |
| `module.gcp-budget[*].google_billing_budget.this` | created by first apply | budgets did not exist before adoption |

## Contract

- Scripts only **create and record**; Terraform validates. The post-import plan
  showing *no diff* is the acceptance test.
- Scripts are short-lived seeds; `ef-mgt-devops` is the permanent home of every
  platform resource. `inventory.yaml` is likewise transient — deleted at Step 5.
- Re-running the scripts is safe (get-or-create); re-running the import list is
  a no-op.

## Sign-off checklist

- [ ] Steps 1–2 complete, `inventory.yaml` committed with real IDs
- [ ] Step 3 import list fully applied
- [ ] Step 5 plan = **No changes**, first platform change merged via PR
- [ ] Step 5: `04-cleanup.sh` run — `sa-adm-bootstrap` deleted,
      `inventory.yaml` removed, local tokens revoked, drift checks on
- [ ] Tag `bootstrap-v1.0` pushed

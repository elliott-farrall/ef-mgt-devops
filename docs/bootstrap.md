# Bootstrap Runbook

The one deliberate exception to code-only operation. Scripts create, Terraform
adopts, the plan proves. Rationale: [design.md](design.md) — Principles and
Integration.

## Prerequisites (assumed in place)

- Accounts exist: GCP organisation, GitHub (`elliott-farrall`), Terraform Cloud,
  Cloudflare — with no further configuration.
- A GCP **billing account is set up and linked to the organisation** with a live
  payment method — projects cannot be created or attached to folders without
  it. (Billing → Billing account; confirm `EF_BILLING_ACCOUNT` matches.)
- Domain `elliott-farrall.phd` registered in Cloudflare.
- Repository `ef-mgt-devops` exists and this scaffold is on `main`.
- Local tooling: `gcloud` authenticated, `terraform`, `jq`, `curl`, `git`.
- Environment variables (never committed):
  `EF_ORG_ID` (or `EF_ORG_DOMAIN` to resolve it), `EF_BILLING_ACCOUNT`,
  `TFC_TOKEN`, `CF_API_TOKEN`, `CF_ACCOUNT_ID`, `GITHUB_TOKEN`.
- `bootstrap/inventory.yaml` present (values are appended by the scripts). It is
  **transient**: it exists to hand IDs from the seed scripts to the import, and
  `05-cleanup.sh` deletes it at close-out.

## Steps

| # | Step | Mode | Command | Outcome |
|---|------|------|---------|---------|
| 1 | Seed GCP | script | `bootstrap/01-gcp.sh` | Hierarchy + IAM skeleton |
| 2 | Seed Terraform Cloud | script | `bootstrap/02-tfc.sh` | Deployment plane exists |
| 3 | Seed Cloudflare | script | `bootstrap/03-cf.sh` | DNS platform seeded |
| 4 | Adopt via import | local TF | `bootstrap/04-import.sh` | Seed state in code's home |
| 5 | Prove the loop | TFC | install the TFC GitHub App (TFC → settings → integrations/github), connect workspace VCS, run plan → **No changes** | Code-only steady state begins |
| 6 | Close out | script + console | `bootstrap/05-cleanup.sh`, then manual checklist | Bootstrapped, closed, documented |

`bootstrap/run.sh` runs Steps 1–4. Step 5 is the PR itself; Step 6 closes out with
`bootstrap/05-cleanup.sh`.

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
- `02-tfc.sh`: global variable set `ef-global` (org/billing/cf IDs);
  workspace `ef-mgt-devops` in project `ef-mgt`, VCS detached until Step 5;
  sensitive variables (`CLOUDFLARE_API_TOKEN`, `GITHUB_TOKEN`) created via
  API — values never pass through this repository.
- `03-cf.sh`: scoped token `ef-tfc-mgt-devops` (Zone.DNS:Edit + Zone.Zone:Read
  on the apex zone only) straight into the TFC sensitive variable; record the
  nameservers for the registrar check.
- `04-import.sh`: extend the import list as the module resources above land.

## Import address list

Authoritative mapping from `04-import.sh`. Extend as module resources land.

| Terraform address | Source (inventory key) | Import ID format |
|---|---|---|
| `module.gcp-folder-root["ef-root"].google_folder.this` | `folder_ef-root` | `folders/<ID>` |
| `module.gcp-folder-plane["ef-mgt"].google_folder.this` | `folder_ef-mgt` | `folders/<ID>` |
| `module.gcp-folder-plane["ef-hub"].google_folder.this` | `folder_ef-hub` | `folders/<ID>` |
| `module.gcp-folder-plane["ef-app"].google_folder.this` | `folder_ef-app` | `folders/<ID>` |
| `module.gcp-folder-ladder["ef-dev"].google_folder.this` | `folder_ef-dev` | `folders/<ID>` |
| `module.gcp-folder-ladder["ef-pre"].google_folder.this` | `folder_ef-pre` | `folders/<ID>` |
| `module.gcp-folder-ladder["ef-prd"].google_folder.this` | `folder_ef-prd` | `folders/<ID>` |
| `module.gcp-project["ef-mgt-devops"].google_project.this` | `landing_project` | `<project-number>` |
| `module.tfc-project["ef-mgt"].tfe_project.this` | `tfc_project_ef-mgt` | `prj-<ID>` |
| `module.tfc-project["ef-hub"].tfe_project.this` | `tfc_project_ef-hub` | `prj-<ID>` |
| `module.tfc-project["ef-app"].tfe_project.this` | `tfc_project_ef-app` | `prj-<ID>` |
| `module.tfc-workspace["ef-mgt-devops"].tfe_workspace.this` | `tfc_workspace` | `<ws-ID>` |
| `module.tfc-workspace["ef-mgt-devops"].tfe_workspace_settings.this` | `tfc_workspace` | `<ws-ID>` |
| `module.cf-zone["elliott-farrall.phd"].cloudflare_zone.this` | `cf_zone_apex` | `<zone-ID>` |
| `module.gh-repository["ef-mgt-devops"].github_repository.this` | `gh_repository` | `ef-mgt-devops` (repo slug) |
| `module.gcp-service-account["sa-<env>-tfc"].google_service_account.this` | `sa_<env>_tfc` | `projects/<project>/serviceAccounts/<email>` |
| `module.gcp-iam-binding[*].*` | created by first apply | IAM bindings are additive; no import required |
| `module.gcp-budget[*].google_billing_budget.this` | created by first apply | budgets did not exist before adoption |

## Contract

- Scripts only **create and record**; Terraform validates. The post-import plan
  showing *no diff* is the acceptance test.
- Scripts are short-lived seeds; `ef-mgt-devops` is the permanent home of every
  platform resource. `inventory.yaml` is likewise transient — deleted at Step 6.
- Re-running the scripts is safe (get-or-create); re-running the import list is
  a no-op.

## Sign-off checklist

- [ ] Steps 1–3 complete, `inventory.yaml` committed with real IDs
- [ ] Step 4 import list fully applied
- [ ] Step 5 plan = **No changes**, first platform change merged via PR
- [ ] Step 6: `05-cleanup.sh` run — `sa-adm-bootstrap` deleted,
      `inventory.yaml` removed, local tokens revoked, drift checks on
- [ ] Tag `bootstrap-v1.0` pushed

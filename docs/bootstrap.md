# Bootstrap Runbook

The one deliberate exception to code-only operation. Scripts create, Terraform
adopts, the plan proves. Full design rationale: *EF Cloud Infrastructure
Framework — Design Document* v1.8, §6.

## Prerequisites (assumed in place)

- Accounts exist: GCP organisation, GitHub (`elliott-farrall`), Terraform Cloud,
  Cloudflare — with no further configuration.
- Domain `elliott-farrall.phd` registered in Cloudflare.
- Repository `ef-mgt-devops` exists and this scaffold is on `main`.
- Local tooling: `gcloud` authenticated, `terraform`, `jq`, `curl`, `git`.
- Environment variables (never committed):
  `EF_ORG_ID`, `EF_BILLING_ACCOUNT`, `TFC_TOKEN`, `CF_API_TOKEN`, `CF_ACCOUNT_ID`.
- `scripts/bootstrap/inventory.yaml` present (values are appended by the scripts).

## Steps

| # | Step | Mode | Command | Outcome |
|---|------|------|---------|---------|
| 1 | Seed GCP | script | `scripts/bootstrap/01-gcp.sh` | Hierarchy + IAM skeleton |
| 2 | Seed Terraform Cloud | script | `scripts/bootstrap/02-tfc.sh` | Deployment plane exists |
| 3 | Seed Cloudflare | script | `scripts/bootstrap/03-cloudflare.sh` | DNS platform seeded |
| 4 | Adopt via import | local TF | `scripts/bootstrap/04-import.sh` | Seed state in code's home |
| 5 | Prove the loop | TFC | connect workspace VCS, run plan → **No changes** | Code-only steady state begins |
| 6 | Close out | console | delete `sa-adm-bootstrap`, revoke local creds, enable drift checks, tag `bootstrap-v1.0` | Bootstrapped, closed, documented |

`scripts/bootstrap.sh` runs Steps 1–3 (and 4 with `--with-import`).

## Import address list

Authoritative mapping from `04-import.sh`. Extend as module resources land.

| Terraform address | Source (inventory key) | Import ID format |
|---|---|---|
| `google_folder.ef_root` | `folder_ef-root` | `folders/<ID>` |
| `google_folder.tree["ef-mgt"]` | `folder_ef-mgt` | `folders/<ID>` |
| `google_folder.tree["ef-hub"]` | `folder_ef-hub` | `folders/<ID>` |
| `google_folder.tree["ef-app"]` | `folder_ef-app` | `folders/<ID>` |
| `google_folder.tree["ef-dev"]` | `folder_ef-dev` | `folders/<ID>` |
| `google_folder.tree["ef-pre"]` | `folder_ef-pre` | `folders/<ID>` |
| `google_folder.tree["ef-prd"]` | `folder_ef-prd` | `folders/<ID>` |
| `google_project.landing` | `landing_project` | `ef-mgt-devops` |
| `module.tfc.tfe_project.planes["ef-mgt"]` | `tfc_project_ef-mgt` | `prj-<ID>` |
| `module.tfc.tfe_project.planes["ef-hub"]` | `tfc_project_ef-hub` | `prj-<ID>` |
| `module.tfc.tfe_project.planes["ef-app"]` | `tfc_project_ef-app` | `prj-<ID>` |
| `module.tfc.tfe_workspace.this` | `tfc_workspace` | `<ws-ID>` |
| `module.tfc.tfe_workspace_settings.this` | `tfc_workspace` | `<ws-ID>` |
| `module.cloudflare.cloudflare_zone.apex` | `cf_zone_apex` | `<zone-ID>` |

## Contract

- Scripts only **create and record**; Terraform validates. The post-import plan
  showing *no diff* is the acceptance test.
- Scripts are short-lived seeds; `ef-mgt-devops` is the permanent home of every
  platform resource.
- Re-running the scripts is safe (get-or-create); re-running the import list is
  a no-op.

## Sign-off checklist

- [ ] Steps 1–3 complete, `inventory.yaml` committed with real IDs
- [ ] Step 4 import list fully applied
- [ ] Step 5 plan = **No changes**, first platform change merged via PR
- [ ] Step 6: `sa-adm-bootstrap` deleted, local tokens revoked, drift checks on
- [ ] Tag `bootstrap-v1.0` pushed

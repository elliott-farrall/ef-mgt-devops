# Bootstrap Runbook

The one deliberate exception to code-only operation. Scripts create, Terraform
adopts, the plan proves. Rationale: [design.md](design.md) — Principles and
Integration.

## Prerequisites (assumed in place)

- Accounts exist: GCP organisation, GitHub (`elliott-farrall`), Terraform Cloud,
  Cloudflare — with no further configuration.
- Domain `elliott-farrall.phd` registered in Cloudflare.
- Repository `ef-mgt-devops` exists and this scaffold is on `main`.
- Local tooling: `gcloud` authenticated, `terraform`, `jq`, `curl`, `git`.
- Environment variables (never committed):
  `EF_ORG_ID`, `EF_BILLING_ACCOUNT`, `TFC_TOKEN`, `CF_API_TOKEN`,
  `CF_ACCOUNT_ID`, `GITHUB_TOKEN`.
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
| `google_project.platform["ef-mgt-devops"]` | `landing_project` | `ef-mgt-devops` |
| `module.tfc.tfe_project.planes["ef-mgt"]` | `tfc_project_ef-mgt` | `prj-<ID>` |
| `module.tfc.tfe_project.planes["ef-hub"]` | `tfc_project_ef-hub` | `prj-<ID>` |
| `module.tfc.tfe_project.planes["ef-app"]` | `tfc_project_ef-app` | `prj-<ID>` |
| `module.tfc.tfe_workspace.registry["ef-mgt-devops"]` | `tfc_workspace` | `<ws-ID>` |
| `module.tfc.tfe_workspace_settings.registry["ef-mgt-devops"]` | `tfc_workspace` | `<ws-ID>` |
| `module.cf.cloudflare_zone.registry["elliott-farrall.phd"]` | `cf_zone_apex` | `<zone-ID>` |
| `module.gh.github_repository.registry["ef-mgt-devops"]` | `gh_repository` | `ef-mgt-devops` (repo slug) |

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

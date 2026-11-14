# Bootstrap Runbook

The one deliberate exception to code-only operation. Scripts create, Terraform
adopts, the plan proves. Rationale: [design.md](design.md) — Principles and
Integration.

## Prerequisites (assumed in place)

- Accounts exist: GCP organisation, GitHub (`elliott-farrall`), Terraform
  Cloud — with no further configuration.
- A GCP **billing account is set up and linked to the organisation** with a live
  payment method — projects cannot be created or attached to folders without
  it.
- The **TFC GitHub App is installed and approved** for the
  `elliott-farrall` GitHub account — the one console action, done once.
  Its name (`Terraform Cloud`) is configured as `tfe.github_app_installation`
  and resolved to the installation ID by `data.tfe_github_app_installation`;
  Terraform then links every workspace to its repository automatically.
- Domain `elliott-farrall.phd` registered (registrar: Cloudflare Registrar —
  a billing relationship, not infrastructure). DNS moves to Cloud DNS as
  Terraform-managed zones; the one-time cutover is pointing the registrar's
  nameservers at the zone's `ns1.googledomains.com` set after the first
  apply.
- Repository `ef-mgt-devops` exists and this scaffold is on `main`.
- Local tooling: `gcloud` authenticated, `terraform`, `jq`, `curl`, `git`.
- Environment variables (never committed): `EF_BILLING_ACCOUNT`, `TFC_TOKEN`,
  `GITHUB_TOKEN`. All other values are read from
  `environments/mgt/organisation.yaml`.

## Steps

| # | Step | Mode | Command | Outcome |
|---|------|------|---------|---------|
| 1–3 | Seed + adopt | script | `scripts/bootstrap.sh` | Folders, projects, workspace, repos imported into state |
| 4 | Prove the loop | TFC | run a full plan → **No changes** (workspace VCS link applied by this run); then point the registrar's nameservers at the Cloud DNS zone | Code-only steady state begins |
| 5 | Close out | script + console | delete `sa-adm-bootstrap`, then manual checklist | Bootstrapped, closed, documented |

## Script scope

`bootstrap/bootstrap.sh` runs Steps 1–3 in one invocation:

- Seeds GCP: folder hierarchy, landing project, API enablement, bootstrap SA
- Seeds TFC: projects (`ef-mgt`, `ef-hub`) and landing workspace
- Adopts all seed-created resources into Terraform state via direct API lookups
- Dry-run validation item: confirm how the run's injected OIDC token reaches
  the google provider's `external_credentials` block in a classic workspace
  (sensitive run-time variable vs ADC external-account config), and wire the
  stack provider block accordingly. `GOOGLE_CREDENTIALS` must never appear:
  the whole chain exists to avoid static keys.

## Import address list

Authoritative mapping from `03-import.sh`. Extend as module resources land.

| Terraform address | Source | Import ID format |
|---|---|---|
| `module.google-folder.google_folder.tree["ef-root"]` | gcloud lookup | `folders/<ID>` |
| `module.google-folder.google_folder.tree["ef-mgt"]` | gcloud lookup | `folders/<ID>` |
| `module.google-folder.google_folder.tree["ef-hub"]` | gcloud lookup | `folders/<ID>` |
| `module.google-folder.google_folder.tree["ef-app"]` | gcloud lookup | `folders/<ID>` |
| `module.google-folder.google_folder.tree["ef-dev"]` | gcloud lookup | `folders/<ID>` |
| `module.google-folder.google_folder.tree["ef-pre"]` | gcloud lookup | `folders/<ID>` |
| `module.google-folder.google_folder.tree["ef-prd"]` | gcloud lookup | `folders/<ID>` |
| `module.google-project["ef-mgt-devops"].google_project.this` | gcloud lookup | `<project-number>` |
| `module.tfe-project["ef-mgt"].tfe_project.this` | TFC API lookup | `prj-<ID>` |
| `module.tfe-project["ef-hub"].tfe_project.this` | TFC API lookup | `prj-<ID>` |
| `module.tfe-project["ef-dev"/"ef-pre"/"ef-prd"]` | created by first apply | lane projects replace `ef-app`; they did not exist before adoption |
| `module.tfe-workspace["ef-mgt-devops"].tfe_workspace.this` | TFC API lookup | `<ws-ID>` |
| `module.tfe-workspace["ef-mgt-devops"].tfe_workspace_settings.this` | TFC API lookup | `<ws-ID>` |
| `module.github-repository["ef-mgt-devops"].github_repository.this` | known constant | `ef-mgt-devops` (repo slug) |
| `module.google-service-account["sa-<env>-tfc"].google_service_account.this` | created by first apply | imported after initial plan proves clean |
| `module.google-workload-identity-provider[*].*`, `module.google-iam-member[*].*` | created by first apply | federation grants and IAM bindings are additive; no import required |
| `module.google-billing-budget[*].google_billing_budget.this` | created by first apply | budgets did not exist before adoption |

## Contract

- Scripts only **create and record**; Terraform validates. The post-import plan
  showing *no diff* is the acceptance test.
- Scripts are short-lived seeds; `ef-mgt-devops` is the permanent home of every
  platform resource.
- Re-running the scripts is safe (get-or-create); re-running the import list is
  a no-op.

## Sign-off checklist

- [ ] `scripts/bootstrap.sh` run, import list fully applied
- [ ] Step 5 plan = **No changes**, first platform change merged via PR
- [ ] Step 5: `04-cleanup.sh` run — `sa-adm-bootstrap` deleted,
      local tokens revoked, drift checks on
- [ ] Tag `bootstrap-v1.0` pushed

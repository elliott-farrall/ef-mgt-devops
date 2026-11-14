# ef-mgt-devops

The EF platform management plane in code: GCP organisation structure,
Terraform Cloud, and Cloudflare — plus the bootstrap scripts and runbook.

- **Status:** scaffolding (`feature/initialise`). Placeholders marked
  `REPLACE_ME`; the `check` block in `infrastructure/main.tf` fails any plan
  that still contains them.
- **Design:** *EF Cloud Infrastructure Framework — Design Document* v1.8.
- **Bring-up:** [`docs/bootstrap.md`](docs/bootstrap.md) — scripts create,
  Terraform adopts, the plan proves.
- **Rules:** [`docs/conventions.md`](docs/conventions.md) — naming, layout,
  code, review.

One input: `environment = mgt`. Everything else is derived in `locals.tf`
from `environments/mgt/*.yaml`. After bootstrap, this repository is the only
way anything in the platform changes.

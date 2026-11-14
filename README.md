# ef-mgt-devops

The EF platform management plane in code: GCP organisation structure,
Terraform Cloud, and Cloudflare — plus the bootstrap scripts and runbook.

- **Status:** scaffolding (`feature/initialise`). All inputs are concrete;
  the `check` block in `infrastructure/main.tf` guards against placeholders
  reappearing.
- **Design:** [`docs/design.md`](docs/design.md) — the design document itself
  (decisions and rationale).
- **Bring-up:** [`docs/bootstrap.md`](docs/bootstrap.md) — scripts create,
  Terraform adopts, the plan proves.
- **Rules:** [`docs/standards.md`](docs/standards.md) — naming, layout,
  code, review.

One input: `environment = mgt`. Everything else is derived in `locals.tf`
from `environments/mgt/*.yaml`. After bootstrap, this repository is the only
way anything in the platform changes.

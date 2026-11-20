# Bootstrap

The one-time bring-up procedure for the platform. Everything here creates
chicken-and-egg resources — the repository itself, its workspace, its
identity — which are imported into Terraform state at the end so the
management plane then manages itself. After the first successful run,
bootstrap is never used again: every change arrives as a PR to `main`.

Read [STANDARDS.md](STANDARDS.md) for the rules this procedure must not
violate and [DESIGN.md](DESIGN.md) for why the platform is shaped the way
it is.

## Prerequisites

Complete every step below before running the script. The script verifies
most of them and fails loudly, but it cannot grant them.

### 1. Tools

The repository flake pins everything. From the repository root:

```sh
nix develop .#bootstrap
```

That shell provides `gcloud`, `terraform`, `gh`, `jq`, `git`,
`shellcheck`, `check-jsonschema`, `yq`, `terraform-docs`, `gettext`,
`tfccli`, and `yaml-language-server`. Outside Nix, install the same set.

### 2. GCP access

The Google identity running the script needs, on the organisation named in
`environments/mgt/organisation.yaml` (resolved by domain):

- `roles/resourcemanager.organizationAdmin` — create the project, and
  grant the platform roles Terraform later adopts.
- Billing viewer/user on the billing account named in `organisation.yaml`
  (`roles/billing.user` minimum; `roles/billing.admin` to link the account
  during project creation).

Authenticate before running:

```sh
gcloud auth login
gcloud config set project <any-project-you-can-query>
```

The script resolves the organisation by domain, creates the project
`ef-mgt-devops` directly under the organisation root, enables its APIs, and
creates `sa-mgt-tfc`.

### 3. Terraform Cloud

- An HCP Terraform account with the organisation named in
  `environments/mgt/organisation.yaml` (`organisation.tfe.organisation`).
!!! note "User token required"
    Team and organisation tokens cannot create or update workspaces
    connected through the GitHub App — the token below must be a **user**
    token, and its owner must have authorised the Terraform Cloud GitHub
    App once in the browser.

```sh
export TF_TOKEN_APP_TERRAFORM_IO=<user-token>
```

- The user who owns that token must authorise the Terraform Cloud GitHub
  App once in the browser (User Settings → Authorized GitHub Apps) — the
  first apply links the workspace to the repository through that
  authorisation.
- A fine-grained GitHub PAT with repository administration on
  `elliott-farrall`, exported as `GITHUB_TOKEN`. Every TFC run needs it for
  the GitHub provider; bootstrap shares it organisation-wide through the
  `platform-tokens` variable set.
- A Cloudflare token with Zone.DNS Edit on `elliott-farrall.phd`, exported
  as `CF_API_TOKEN`. The DNS records run through the Cloudflare provider;
  bootstrap shares the token through `platform-tokens` and imports the
  existing records into state.
- The org must be able to run remote workspaces (Team & Business tiers or
  above).

### 4. GitHub App installation

!!! warning "One-time console action"
    Installing the Terraform Cloud GitHub App is the one sanctioned
    console action in the platform — GitHub requires an interactive web
    flow to install an application, and no API can do it for you.

1. Open <https://app.terraform.io/app/settings/organizations/<org>/github-app>
   (or GitHub → organisation → Settings → GitHub Apps).
2. Install the Terraform Cloud app on the GitHub organisation
   `elliott-farrall`, granting repository access.

Bootstrap step 2.2 verifies the installation by name and aborts if it is
missing. The installation name must match `organisation.gh.owner`.

### 5. Configuration review

Check `environments/mgt/*.yaml` before running — the script and the first
apply consume every value in them:

- `organisation.yaml` — domain, region, billing account display name, TFC
  org and hostname, GitHub owner, and the GitHub App installation name.
- `budgets.yaml` — budget alerts (defaults are sensible).
- `zones.yaml` — DNS zones and record sets (must exist or the apply will
  create them).
- `environments.yaml` — `mgt/devops` must exist with `default: true` and
  its `services` list; the other environments stay bare.

## Running

From the repository root, with `TF_TOKEN_APP_TERRAFORM_IO` and
`GITHUB_TOKEN` exported:

```sh
nix develop .#bootstrap -c ./bootstrap/run.sh
```

The script runs four phases and is idempotent — reruns skip what already
exists:

1. **GCP** — resolve the organisation by domain, create `ef-mgt-devops`
   under the organisation root, enable the configured APIs, create
   `sa-mgt-tfc`.
2. **Terraform Cloud** — verify token and org access, verify the GitHub App
   installation, create TFC project `ef-mgt` and workspace
   `ef-mgt-devops`, then seed the credential layer: the organisation-wide
   variable set `platform-tokens` (`GITHUB_TOKEN`, `TFE_TOKEN`,
   `CLOUDFLARE_API_TOKEN` — shared with every workspace), and set the
   workspace to local execution for the first apply.
3. **Imports** — derive the import addresses and render
   `infrastructure/bootstrap.tf` from `imports.tf.tmpl`. The live
   Cloudflare DNS records are imported through the committed
   `infrastructure/imports.tf`, which applies in the same run.
4. **Deploy** — `terraform init` against the remote backend, then a single
   local-execution `apply` that imports the bootstrap resources into state
   and creates everything else (identities, pools, providers, bindings,
   budgets), running under your own Google identity. The workspace
   variables it creates switch every later run to workload identity
   federation and remote execution — there are no temporary credentials
   and no close-out step.

   !!! note "The first apply is local"
    Phase 4 runs locally under your own Google identity and sets the
    workspace to remote execution at the end. Never rerun phase 4 after
    that switch — the workspace is remote and the run would fail
    authentication. Rerun the whole script if a full bring-up is ever
    needed again.

## After the first run

- `infrastructure/bootstrap.tf` is transient — it exists only for the
  first apply. Delete it once applied (or leave it; it references imported
  resources and is harmless, but it is gitignored and must never be
  committed).
- The workspace `ef-mgt-devops` now runs the platform from `main`. Every
  future change is a PR: CI validates, TFC plans on the PR, merge triggers
  the run.
- Verify in the GCP console that the org now contains the project, WIF
  pools, and service account expected from [DESIGN.md](DESIGN.md), then
  stay out of the console — manual changes are drift.

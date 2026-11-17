# ef-mgt-devops

Management plane for my personal cloud landing zone: GitHub
organisations, Google Cloud, and Terraform Cloud, provisioned entirely
from a small set of YAML files through Terraform. Landing a new project
is a data change, never new machinery.

## Documentation

| File | Purpose |
|------|---------|
| [docs/DESIGN.md](docs/DESIGN.md) | Architecture decisions and rationale |
| [docs/STANDARDS.md](docs/STANDARDS.md) | Binding rules — read before changing anything structural |
| [docs/BOOTSTRAP.md](docs/BOOTSTRAP.md) | One-time bring-up procedure |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Development workflow and conventions |
| [CHANGELOG.md](CHANGELOG.md) | What changed, and when |

## Layout

```
├── environments/mgt/       # YAML inputs — the platform is defined here
├── .schemas/environment/   # JSON Schema per config file
├── infrastructure/         # Terraform: five function modules + wiring
├── scripts/bootstrap.sh    # One-time bring-up
└── docs/                   # Design, standards, bootstrap
```

## Getting started

```sh
nix develop        # pinned toolchain
make help          # available checks
make ci            # run every check
```

First bring-up of the platform itself: follow
[docs/BOOTSTRAP.md](docs/BOOTSTRAP.md).

## How it works

Five function modules — `environment`, `project`, `module`, `zone`,
`budget` — consume the merged YAML and create everything: GCP folders and
projects, TFC projects and workspaces, GitHub repositories, workload
identity federation, DNS, and budgets. The rules for how the code is
organised live in [docs/STANDARDS.md](docs/STANDARDS.md); this repository
is the template for future `ef-*` repositories.

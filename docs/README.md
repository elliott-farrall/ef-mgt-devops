# My Cloud Landing Zone

Management plane for my personal cloud landing zone: GitHub
organisations, Google Cloud, and Terraform Cloud, provisioned entirely
from a small set of YAML files through Terraform. Landing a new project
is a data change, never new machinery.

## Documentation

| File | Purpose |
|------|---------|
| [DESIGN.md](DESIGN.md) | Architecture decisions and rationale |
| [STANDARDS.md](STANDARDS.md) | Binding rules — read before changing anything structural |
| [bootstrap/GUIDE.md](https://github.com/elliott-farrall/ef-mgt-devops/blob/main/bootstrap/GUIDE.md) | One-time bring-up procedure |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Development workflow and conventions |
| [CHANGELOG.md](CHANGELOG.md) | What changed, and when |

## Layout

```
├── environments/mgt/       # YAML inputs — the platform is defined here
├── .schemas/environment/   # JSON Schema per config file
├── infrastructure/         # Terraform: six function modules + wiring
├── bootstrap/              # run.sh, import template, bring-up guide
└── docs/                   # This site — design, standards, contributing
```

## Getting started

```sh
nix develop        # pinned toolchain
make help          # available checks
make ci            # run every check
```

First bring-up of the platform itself: follow
[bootstrap/GUIDE.md](https://github.com/elliott-farrall/ef-mgt-devops/blob/main/bootstrap/GUIDE.md).

## How it works

Five function modules — `environment`, `project`, `module`, `record`,
`budget` — consume the merged YAML and create everything: GCP folders and
projects, TFC projects and workspaces, GitHub repositories, workload
identity federation, DNS, and budgets. The rules for how the code is
organised live in [STANDARDS.md](STANDARDS.md); this repository is the
template for future `ef-*` repositories.

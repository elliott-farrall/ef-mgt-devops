# AGENTS

This repository is a landing-zone management plane. To work on it:

1. Read `docs/STANDARDS.md` first — it is binding and applies to every
   change, including naming, file layout, module structure, and YAML
   style. `docs/DESIGN.md` explains why the platform looks the way it does.
2. The platform is data: adding an environment, project, module repo,
   record, or budget is a YAML change in `environments/mgt/`, validated by
   its schema in `.schemas/environment/`. Never add machinery to do what
   data can do.
3. Terraform is organised by function — `environment`, `project`,
   `module`, `zone`, `budget` modules — driven by one plural local per
   module in `infrastructure/locals.tf`. `main.tf` is wiring only.
4. Run `nix develop` for the pinned toolchain, `make ci` for every check.
   Checks print one tick/cross line each; failures show the tool output.
5. Every PR updates `CHANGELOG.md` (see `CONTRIBUTING.md`); releases are
   cut manually from it.
6. Bring-up procedures live in `bootstrap/GUIDE.md`. Bootstrap is
   one-time; steady state is PR-only.

This file and the docs it points at must stay in sync with the code in
the same PR that changes either.

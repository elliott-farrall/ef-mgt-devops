# Changelog

All notable changes to this project are documented here. Update this file
in the same PR as the change it describes — see CONTRIBUTING.md.

## [Unreleased]

### Added

- Flat environments model: mgt, hub, dev, pre, prd under the organisation root.
- Function modules: environment, project, module, zone, budget.
- Repository rulesets: CI + TFC plan enforcement for everyone, review bypassed only via pull requests.
- One folder per environment; environment identities create projects inside their own folder.
- Organisation-wide token variable set `platform-tokens`, provisioned by bootstrap.

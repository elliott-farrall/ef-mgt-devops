# Contributing

## Setup

```sh
nix develop     # pinned toolchain — no other dependencies
make help       # list every check
```

## Checks

`make ci` runs every check. Each prints one line: ✓ when it passes, ✗
with the tool's output when it fails. Run the full set before every push;
CI runs exactly `make ci` on every pull request.

## Branches and commits

- Branches: `<type>/<kebab-name>`, or `<type>/<key>-<kebab-name>` when the
  work has a Linear ticket — the lowercased key (e.g. `web-123`) links the
  branch to the ticket: `feature/web-123-add-auth`. Type is one of
  `feature`, `fix`, `hotfix`, `chore`, `docs`, `refactor`, `test`, `perf`,
  `build`, `ci`, `revert`. Enforced by the `Branch name` check.
- Commits: [Conventional Commits](https://www.conventionalcommits.org/) —
  `feat:`, `fix:`, `perf:`, `BREAKING CHANGE:` carry semantic meaning;
  everything else is unchanged plumbing. Enforced by the
  `Conventional commits` check.

## Pull requests

1. Branch from a fresh `main`; rebase and resolve conflicts yourself.
2. Every PR updates `CHANGELOG.md` under the current unreleased heading.
   One line per user-visible change:
   - `feat:` → **Added**
   - `fix:` → **Fixed**
   - `perf:` → **Changed**
   - anything else → **Other**
   Docs-only and plumbing changes may be skipped if they would say
   nothing worth reading.
3. `make ci` passes locally.
4. Keep PRs small and focused; the description says why, not what.
5. Review requirements follow the repository rulesets — agents and
   collaborators need maintainer approval; the maintainer's own PRs need
   only green checks.

## Versioning

Versions are cut manually from `CHANGELOG.md` when a release is wanted:
summarise the unreleased section into a dated `## [x.y.z]` heading
following [Keep a Changelog](https://keepachangelog.com/) semantics —
feat → minor bump, fix → patch, breaking → major. Tag the commit and
push the tag. There is no release automation to maintain.

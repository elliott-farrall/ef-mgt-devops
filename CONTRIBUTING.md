# Contributing

## Development

Set up your environment:

```bash
nix develop
```

Run all checks locally:

```bash
make all
```

## Commit & Branch Conventions

- Branches: `<type>/<kebab-name>` (feature|fix|hotfix|chore|docs|refactor|test|perf|build|ci|revert)
- Commits: [Conventional Commits](https://www.conventionalcommits.org/)
- PR title: same as commit message convention
- The release GitHub App reads PR titles/bodies and generates `CHANGELOG.md` + version tags automatically on every merge to `main`. No manual steps required.

### How releases work

Commits are grouped semantically. Only commits with a prefix listed below contribute to changelog entries and version bumps. Other types (`chore`, `docs`, `refactor`, etc.) appear in the changelog but don't trigger version changes:

| Prefix       | Version bump  | Changelog section  |
| ------------ | ------------- | ------------------ |
| `feat:`      | minor         | Features           |
| `fix:`       | patch         | Bug Fixes          |
| `BREAKING CHANGE:` | major   | BREAKING CHANGES   |
| `hotfix:`    | patch         | Hotfixes           |
| `perf:`      | patch/minor   | Performance        |

Releases use standard conventional commit prefixes: `feat`, `fix`, `perf`, `BREAKING CHANGE` for semantic versions; everything else goes into "Other Changes" at no cost. You never need to touch the changelog or version numbers yourself — the release action handles both on every push to `main`.


## Pull Requests

1. Rebase on `main`, resolve conflicts yourself
2. All checks must pass (`make all`)
3. Keep PRs small and focused; describe the "why" not the "what"
4. Assign at least one reviewer; address feedback promptly

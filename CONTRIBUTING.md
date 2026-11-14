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

## Pull Requests

1. Rebase on `main`, resolve conflicts yourself
2. All checks must pass (`make all`)
3. Keep PRs small and focused; describe the "why" not the "what"
4. Assign at least one reviewer; address feedback promptly

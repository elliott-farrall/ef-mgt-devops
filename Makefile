SHELL := /usr/bin/env bash

.PHONY: help yaml-schema yaml-config yaml-style terraform-fmt terraform-validate terraform git-branch bash-shell git-commit terraform-docs docs-changelog all

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[1m%-20s\033[0m %s\n", $$1, $$2}'

# ── YAML ────────────────────────────────────────────────────────────────
yaml-schema: ## Validate schemas against metaschema
	check-jsonschema --check-metaschema .schemas/environment/*.yaml

yaml-config: ## Validate config files against their schemas
	@for env_dir in environments/*/; do \
	  for f in "$$env_dir"*.yaml; do \
	    name=$$(basename "$$f"); \
	    schema=".schemas/environment/$$name"; \
	    [ -f "$$schema" ] || { echo "::error file=$$f::no schema $$schema"; exit 1; }; \
	    check-jsonschema --schemafile "$$schema" "$$f"; \
	  done \
	done

yaml-lint: ## Lint YAML with yamllint defaults (block style enforced by flow-sequence/braces rules); line-length disabled — DNS record values are unbreakable
	yamllint -d "{extends: default, rules: {line-length: disable}}" .schemas/environment environments

yaml-style: ## Check YAML is block-style with plain scalars
	@files=$$(ls environments/*/*.yaml 2>/dev/null || true); \
	[ -z "$$files" ] && exit 0; \
	if grep -rnE '(: *[([{"])|(^[[:space:]]*- *\{)' $$files; then \
	  echo "YAML config must be block style with plain scalars (see docs/STANDARDS.md)"; exit 1; fi

# ── Terraform ───────────────────────────────────────────────────────────
terraform-fmt: ## Format-check Terraform files
	terraform fmt -recursive -check infrastructure

terraform-init: ## Initialize Terraform configuration
	terraform init -backend=false -chdir=infrastructure

terraform-validate: terraform-init ## Validate Terraform configuration
	terraform validate -chdir=infrastructure

terraform-docs: ## Verify module READMEs are current
	@ROOT=$$(git rev-parse --show-toplevel); \
	for dir in infrastructure infrastructure/modules/*/; do \
	  (cd "$$ROOT/$$dir" && terraform-docs markdown table . --output-file README.md) || exit 1; \
	done; \
	cd "$$ROOT" && git diff --exit-code -- infrastructure/README.md 'infrastructure/modules/*/README.md' || \
	  { echo "::error::terraform-docs READMEs are stale — run make terraform-docs"; exit 1; }

terraform: terraform-fmt terraform-validate terraform-docs ## Run all Terraform checks

# ── Git ─────────────────────────────────────────────────────────────────
git-branch: ## Enforce branch name convention
	@BRANCH=$${BRANCH_NAME:-$$GITHUB_HEAD_REF}; \
	if [ -z "$$BRANCH" ]; then BRANCH=$$(git symbolic-ref --short HEAD 2>/dev/null); fi; \
	echo "$$BRANCH" | grep -Eq '^(feature|fix|hotfix|chore|docs|refactor|test|perf|build|ci|revert)/[a-z0-9][a-z0-9._-]*$$' || \
	{ echo "Branch '$$BRANCH' must be <type>/<kebab-name>"; exit 1; }

git-commit: ## Validate commit messages follow Conventional Commits
	@commits=$$(git log "$${GITHUB_BASE_REF}..HEAD" --pretty=format:'%s' || true); \
	[ -z "$$commits" ] && exit 0; \
	echo "$$commits" | commitlint

# ── Bash ────────────────────────────────────────────────────────────────
bash-shell: ## Lint and syntax-check shell scripts
	shellcheck -x -S error scripts/*.sh
	@for s in scripts/*.sh; do bash -n "$$s"; done

# ── Docs ────────────────────────────────────────────────────────────────
docs-changelog: ## Auto-generate CHANGELOG.md from git history (conventional commits)
	@git-cliff --output CHANGELOG.md

# ── All ─────────────────────────────────────────────────────────────────
all: yaml-schema yaml-config yaml-lint yaml-style terraform-fmt bash-shell git-branch git-commit terraform-docs ## Run all checks (excluding auto-generated CHANGELOG.md)

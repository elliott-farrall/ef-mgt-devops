SHELL := /usr/bin/env bash

.PHONY: help yaml-schema yaml-config yaml-style terraform-fmt terraform-validate terraform git-branch bash-shell docs-readme docs-changelog git-commit all

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

yaml-style: ## Check YAML is block-style with plain scalars
	@files=$$(ls environments/*/*.yaml 2>/dev/null || true); \
	[ -z "$$files" ] && exit 0; \
	if grep -rnE '(: *[([{"])|(^[[:space:]]*- *\{)' $$files; then \
	  echo "YAML config must be block style with plain scalars (see docs/standards.md)"; exit 1; fi

# ── Terraform ───────────────────────────────────────────────────────────
terraform-fmt: ## Format-check Terraform files
	terraform fmt -recursive -check infrastructure

terraform-validate: ## Validate Terraform configuration
	cd infrastructure && terraform init -backend=false && terraform validate

terraform: terraform-fmt terraform-validate ## Run all Terraform checks

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
docs-readme: ## Generate README.md from Terraform modules
	@cd infrastructure && terraform-docs markdown table . \
	  --output-file ../README.md \
	  --output-mode inject \
	  --hide "providers,data-sources,resources,requirements" 2>/dev/null || true

docs-changelog: ## Auto-generate CHANGELOG.md from git history (conventional commits)
	@git-cliff --output CHANGELOG.md

# ── All ─────────────────────────────────────────────────────────────────
all: yaml-schema yaml-config yaml-style terraform-fmt bash-shell git-branch git-commit docs-readme docs-changelog ## Run all checks

SHELL := /usr/bin/env bash

comma := ,

# ── Check runner ─────────────────────────────────────────────────────────
# One tick/cross line per check; tool output appears only on failure.
define check
	@if out=$$($1 2>&1); then printf '  ✓ %s\n' '$(2)'; \
	else printf '  ✗ %s\n' '$(2)'; printf '%s\n' "$$out"; false; fi
endef

.PHONY: help ci yaml-schema yaml-config yaml-lint yaml-style terraform-fmt terraform-validate bash-shell git-branch git-commit docs-build

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[1m%-20s\033[0m %s\n", $$1, $$2}'

# ── YAML ─────────────────────────────────────────────────────────────────
yaml-schema: ## Schema files validate against the metaschema
	$(call check,check-jsonschema --check-metaschema .schemas/environment/*.yaml,YAML schemas)

YAML_CONFIG := for env_dir in environments/*/; do \
	for f in "$$env_dir"*.yaml; do \
	name=$$(basename "$$f"); \
	check-jsonschema --schemafile ".schemas/environment/$$name" "$$f" || exit 1; \
	done; \
	done

yaml-config: ## Config files validate against their schemas
	$(call check,$(YAML_CONFIG),YAML config against schemas)

yaml-lint: ## yamllint defaults; line-length disabled — DNS record values are unbreakable
	$(call check,yamllint -d '{extends: default$(comma) rules: {line-length: disable}}' .schemas/environment environments,YAML lint)

yaml-style: ## YAML is block style with plain scalars
	$(call check,if files=$$(ls environments/*/*.yaml 2>/dev/null) && [ -n "$$files" ] && grep -rnE '(: *[([{"])|(^[[:space:]]*- *\{)' $$files; then echo block-style-only; fi,YAML style)

# ── Terraform ────────────────────────────────────────────────────────────
terraform-fmt: ## Terraform files are formatted
	$(call check,terraform fmt -recursive -check infrastructure,Terraform fmt)

TERRAFORM_VALIDATE := terraform -chdir=infrastructure init -backend=false -input=false >/dev/null && \
	terraform -chdir=infrastructure validate

terraform-validate: ## Terraform configuration is valid
	$(call check,$(TERRAFORM_VALIDATE),Terraform validate)

# ── Bash ─────────────────────────────────────────────────────────────────
bash-shell: ## Shell scripts pass shellcheck and parse
	$(call check,shellcheck -x -S error bootstrap/*.sh && for s in bootstrap/*.sh; do bash -n "$$s"; done,Shell scripts)

# ── Git ──────────────────────────────────────────────────────────────────
git-branch: ## Branch name follows <type>/<kebab-name>
	$(call check,br=$${BRANCH_NAME:-$$GITHUB_HEAD_REF}; [ -z "$$br" ] && br=$$(git symbolic-ref --short HEAD 2>/dev/null); echo "$$br" | grep -Eq '^(feature|fix|hotfix|chore|docs|refactor|test|perf|build|ci|revert)/([a-z]+-[0-9]+-)?[a-z0-9][a-z0-9._-]*$$',Branch name)

GIT_COMMIT := commits=$$(git log "$${GITHUB_BASE_REF}..HEAD" --pretty=format:'%s' 2>/dev/null || true); \
	if [ -n "$$commits" ]; then echo "$$commits" | commitlint; fi

git-commit: ## Commits follow Conventional Commits
	$(call check,$(GIT_COMMIT),Conventional commits)

# ── Docs ─────────────────────────────────────────────────────────────────
docs-build: ## Documentation builds strictly
	$(call check,mkdocs build --strict --site-dir /tmp/docs-site,Docs build)

# ── CI ───────────────────────────────────────────────────────────────────
ci: yaml-schema yaml-config yaml-lint yaml-style terraform-fmt bash-shell git-branch git-commit docs-build terraform-validate ## Run all CI checks

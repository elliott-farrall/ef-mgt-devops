## [unreleased]

### 🐛 Bug Fixes

- Fall back to git symbolic-ref for local git-branch checks
- Docs-changelog writes unconditionally, update README from terraform-docs
- Update billing_account_id to match schema pattern
- Update billing_id schema, refresh CHANGELOG

### 📚 Documentation

- Record WIF token-glue dry-run item; GOOGLE_CREDENTIALS stays banned
- Add detailed resource map section to design.md
- Rename docs to uppercase, add session work
- Regenerate CHANGELOG from squashed history
- Regenerate CHANGELOG from squashed history
- Regenerate CHANGELOG

### 🚜 Refactor

- Split devshells into default and bootstrap

### ⚙️ Miscellaneous Tasks

- Add contribution guides, issue/PR templates, and CI pipeline restructuring
- Refresh CHANGELOG from current history
- Refresh CHANGELOG
- Add cliff.toml config, refresh CHANGELOG

### 💼 Other

- Initial repository layout per design doc v1.8 §5.1
- YAML inputs drive everything; this plane provisions itself and the rest
- Nest workspaces inside projects; drop redundant project key
- Split sa-adm-tfc; drop additional_roles machinery
- GBP, single ef-budget-total at 30/month account-wide
- One gcp_folders collection with depth tags
- Eleven top-levels — config, one per module, one for checks
- Three arguments, full stop
- Resolve GitHub App installation by name via data source
- Split YAML by setup concern, not by platform
- Project types — software, infrastructure, module
- Remove GITHUB_TOKEN requirement
- Replace curl with tfccli for TFC operations
- Consolidate all YAML reads into single config section
- Remove comment header from imports.tf.tmpl
- Indent substep logs with tree-style prefixes
- Restore step numbers to headers as 1) 2) 3) 4)
- Move Terraform backend config to step 0.3 prerequisites
- Use tfc CLI instead of raw curl for auth verification

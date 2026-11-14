# ef-mgt-devops

The EF platform management plane in code: GCP organisation structure, Terraform Cloud, and DNS — plus the bootstrap scripts and runbook

<!-- BEGIN_TF_DOCS -->
## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_github-repository"></a> [github-repository](#module\_github-repository) | ./modules/github-repository | n/a |
| <a name="module_google-billing-budget"></a> [google-billing-budget](#module\_google-billing-budget) | ./modules/google-billing-budget | n/a |
| <a name="module_google-dns-managed-zone"></a> [google-dns-managed-zone](#module\_google-dns-managed-zone) | ./modules/google-dns-managed-zone | n/a |
| <a name="module_google-folder"></a> [google-folder](#module\_google-folder) | ./modules/google-folder | n/a |
| <a name="module_google-iam-member"></a> [google-iam-member](#module\_google-iam-member) | ./modules/google-iam-member | n/a |
| <a name="module_google-project"></a> [google-project](#module\_google-project) | ./modules/google-project | n/a |
| <a name="module_google-service-account"></a> [google-service-account](#module\_google-service-account) | ./modules/google-service-account | n/a |
| <a name="module_google-workload-identity-pool"></a> [google-workload-identity-pool](#module\_google-workload-identity-pool) | ./modules/google-workload-identity-pool | n/a |
| <a name="module_google-workload-identity-provider"></a> [google-workload-identity-provider](#module\_google-workload-identity-provider) | ./modules/google-workload-identity-provider | n/a |
| <a name="module_tfe-project"></a> [tfe-project](#module\_tfe-project) | ./modules/tfe-project | n/a |
| <a name="module_tfe-registry-module"></a> [tfe-registry-module](#module\_tfe-registry-module) | ./modules/tfe-registry-module | n/a |
| <a name="module_tfe-workspace"></a> [tfe-workspace](#module\_tfe-workspace) | ./modules/tfe-workspace | n/a |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment slot selecting environments/<name>/ YAML inputs, naming, labels, and policy. The only top-level variable; no default by design. | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->

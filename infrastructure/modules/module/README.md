<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_github"></a> [github](#requirement\_github) | >= 6.0 |
| <a name="requirement_tfe"></a> [tfe](#requirement\_tfe) | >= 0.84 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_github"></a> [github](#provider\_github) | >= 6.0 |
| <a name="provider_tfe"></a> [tfe](#provider\_tfe) | >= 0.84 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [github_branch_protection.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/branch_protection) | resource |
| [github_repository.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository) | resource |
| [github_repository_vulnerability_alerts.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_vulnerability_alerts) | resource |
| [tfe_registry_module.this](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/registry_module) | resource |
| [tfe_github_app_installation.this](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/data-sources/github_app_installation) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_description"></a> [description](#input\_description) | Repository description; defaults to the repository name. | `string` | `null` | no |
| <a name="input_github_app_installation"></a> [github\_app\_installation](#input\_github\_app\_installation) | Name of the TFC GitHub App installation authorised for the repository. | `string` | n/a | yes |
| <a name="input_module_provider"></a> [module\_provider](#input\_module\_provider) | Provider segment of the registry address; these are GCP modules. | `string` | `"google"` | no |
| <a name="input_name"></a> [name](#input\_name) | Module name in the registry; derived from the repository name. | `string` | n/a | yes |
| <a name="input_organization"></a> [organization](#input\_organization) | TFC organisation hosting the registry. | `string` | n/a | yes |
| <a name="input_protection"></a> [protection](#input\_protection) | Overrides for the main-branch protection platform defaults. | `any` | `{}` | no |
| <a name="input_repo"></a> [repo](#input\_repo) | GitHub repository name. | `string` | n/a | yes |
| <a name="input_repository_id"></a> [repository\_id](#input\_repository\_id) | VCS identifier, owner/repo. | `string` | n/a | yes |
| <a name="input_settings"></a> [settings](#input\_settings) | Overrides for github\_repository platform defaults. | `any` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_github_repository"></a> [github\_repository](#output\_github\_repository) | The GitHub repository resource. |
| <a name="output_tfe_registry_module"></a> [tfe\_registry\_module](#output\_tfe\_registry\_module) | The private registry module resource. |
<!-- END_TF_DOCS -->
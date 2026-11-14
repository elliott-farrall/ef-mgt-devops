<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_tfe"></a> [tfe](#requirement\_tfe) | >= 0.84 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_tfe"></a> [tfe](#provider\_tfe) | >= 0.84 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [tfe_registry_module.this](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/registry_module) | resource |
| [tfe_github_app_installation.this](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/data-sources/github_app_installation) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_github_app_installation"></a> [github\_app\_installation](#input\_github\_app\_installation) | Name of the TFC GitHub App installation authorised for the repository. | `string` | n/a | yes |
| <a name="input_module_provider"></a> [module\_provider](#input\_module\_provider) | Provider segment of the registry address; these are GCP modules. | `string` | `"google"` | no |
| <a name="input_name"></a> [name](#input\_name) | Module name in the registry. | `string` | n/a | yes |
| <a name="input_organization"></a> [organization](#input\_organization) | TFC organisation hosting the registry. | `string` | n/a | yes |
| <a name="input_repository"></a> [repository](#input\_repository) | VCS identifier, owner/repo. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_tfe_registry_module"></a> [tfe\_registry\_module](#output\_tfe\_registry\_module) | Private registry module resource. |
<!-- END_TF_DOCS -->
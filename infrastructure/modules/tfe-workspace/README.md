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
| [tfe_variable.environment](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/variable) | resource |
| [tfe_variable.gcp_impersonate_service_account](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/variable) | resource |
| [tfe_variable.wif_provider](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/variable) | resource |
| [tfe_workspace.this](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/workspace) | resource |
| [tfe_workspace_settings.this](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/workspace_settings) | resource |
| [tfe_github_app_installation.this](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/data-sources/github_app_installation) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_auto_apply"></a> [auto\_apply](#input\_auto\_apply) | Whether to automatically apply changes when a Terraform plan is successful. | `bool` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment slot injected as the terraform environment variable. | `string` | n/a | yes |
| <a name="input_gcp_service_account_email"></a> [gcp\_service\_account\_email](#input\_gcp\_service\_account\_email) | Service account the run impersonates once its workload identity token is exchanged. | `string` | n/a | yes |
| <a name="input_github_app_installation"></a> [github\_app\_installation](#input\_github\_app\_installation) | Name of the TFC GitHub App installation; resolved by data.tfe\_github\_app\_installation within this module. | `string` | n/a | yes |
| <a name="input_github_owner"></a> [github\_owner](#input\_github\_owner) | GitHub account owning the repository. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Workspace name; unique across the platform. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Owning TFC project ID from module.tfe-project. | `string` | n/a | yes |
| <a name="input_repo"></a> [repo](#input\_repo) | GitHub repository this workspace builds. | `string` | n/a | yes |
| <a name="input_wif_provider"></a> [wif\_provider](#input\_wif\_provider) | Full WIF provider resource name this workspace authenticates through; exposed to runs as the WIF\_PROVIDER variable. | `string` | n/a | yes |
| <a name="input_working_directory"></a> [working\_directory](#input\_working\_directory) | Terraform root inside the repository. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_tfe_variable_environment"></a> [tfe\_variable\_environment](#output\_tfe\_variable\_environment) | The environment slot variable injected into the workspace as a terraform variable. |
| <a name="output_tfe_variable_gcp_impersonate_service_account"></a> [tfe\_variable\_gcp\_impersonate\_service\_account](#output\_tfe\_variable\_gcp\_impersonate\_service\_account) | The GCP service account variable used for impersonation after workload identity token exchange. |
| <a name="output_tfe_variable_wif_provider"></a> [tfe\_variable\_wif\_provider](#output\_tfe\_variable\_wif\_provider) | The WIF provider variable exposed to runs as an environment variable. |
| <a name="output_tfe_workspace"></a> [tfe\_workspace](#output\_tfe\_workspace) | The TFE workspace created for this infrastructure project. |
| <a name="output_tfe_workspace_settings"></a> [tfe\_workspace\_settings](#output\_tfe\_workspace\_settings) | Workspace settings resource (execution mode set to remote). |
<!-- END_TF_DOCS -->
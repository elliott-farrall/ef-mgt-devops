<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_github"></a> [github](#requirement\_github) | >= 6.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 6.0 |
| <a name="requirement_tfe"></a> [tfe](#requirement\_tfe) | >= 0.84 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_github"></a> [github](#provider\_github) | >= 6.0 |
| <a name="provider_google"></a> [google](#provider\_google) | >= 6.0 |
| <a name="provider_tfe"></a> [tfe](#provider\_tfe) | >= 0.84 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [github_branch_protection.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/branch_protection) | resource |
| [github_repository.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository) | resource |
| [github_repository_vulnerability_alerts.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_vulnerability_alerts) | resource |
| [google_project.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project) | resource |
| [google_project_service.apis](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [tfe_variable.environment](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/variable) | resource |
| [tfe_variable.gcp_provider_auth](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/variable) | resource |
| [tfe_variable.gcp_run_service_account](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/variable) | resource |
| [tfe_variable.gcp_workload_identity_provider](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/variable) | resource |
| [tfe_workspace.this](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/workspace) | resource |
| [tfe_workspace_settings.this](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/workspace_settings) | resource |
| [tfe_github_app_installation.this](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/data-sources/github_app_installation) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_auto_apply"></a> [auto\_apply](#input\_auto\_apply) | Whether to automatically apply changes when a Terraform plan is successful. | `bool` | n/a | yes |
| <a name="input_billing_account_id"></a> [billing\_account\_id](#input\_billing\_account\_id) | GCP billing account to attach. | `string` | n/a | yes |
| <a name="input_description"></a> [description](#input\_description) | Repository description; defaults to the repository name. | `string` | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment slot injected as the terraform environment variable. | `string` | n/a | yes |
| <a name="input_gcp_service_account_email"></a> [gcp\_service\_account\_email](#input\_gcp\_service\_account\_email) | Service account the run impersonates once its workload identity token is exchanged. | `string` | n/a | yes |
| <a name="input_github_app_installation"></a> [github\_app\_installation](#input\_github\_app\_installation) | Name of the TFC GitHub App installation; resolved by data.tfe\_github\_app\_installation within this module. | `string` | n/a | yes |
| <a name="input_github_owner"></a> [github\_owner](#input\_github\_owner) | GitHub account owning the repository. | `string` | n/a | yes |
| <a name="input_labels"></a> [labels](#input\_labels) | Mandatory label set. | `map(string)` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Full project name; doubles as the GCP project id and the workspace name. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Owning TFC project ID from module.environment. | `string` | n/a | yes |
| <a name="input_protection"></a> [protection](#input\_protection) | Overrides for the main-branch protection platform defaults. | `any` | `{}` | no |
| <a name="input_repo"></a> [repo](#input\_repo) | GitHub repository name. | `string` | n/a | yes |
| <a name="input_services"></a> [services](#input\_services) | GCP APIs to enable on the project. | `list(string)` | n/a | yes |
| <a name="input_settings"></a> [settings](#input\_settings) | Overrides for github\_repository platform defaults. | `any` | `{}` | no |
| <a name="input_wif_provider"></a> [wif\_provider](#input\_wif\_provider) | Full WIF provider resource name this workspace authenticates through; exposed to runs as the WIF\_PROVIDER variable. | `string` | n/a | yes |
| <a name="input_working_directory"></a> [working\_directory](#input\_working\_directory) | Terraform root inside the repository. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_github_repository"></a> [github\_repository](#output\_github\_repository) | The GitHub repository resource. |
| <a name="output_google_project"></a> [google\_project](#output\_google\_project) | The GCP project resource. |
| <a name="output_google_project_service"></a> [google\_project\_service](#output\_google\_project\_service) | Map of enabled GCP APIs keyed by service name. |
| <a name="output_tfe_workspace"></a> [tfe\_workspace](#output\_tfe\_workspace) | The TFC workspace resource. |
<!-- END_TF_DOCS -->
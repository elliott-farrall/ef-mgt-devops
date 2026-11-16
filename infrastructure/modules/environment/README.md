<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 6.0 |
| <a name="requirement_tfe"></a> [tfe](#requirement\_tfe) | >= 0.84 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >= 6.0 |
| <a name="provider_tfe"></a> [tfe](#provider\_tfe) | >= 0.84 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_billing_account_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/billing_account_iam_member) | resource |
| [google_folder.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/folder) | resource |
| [google_folder_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/folder_iam_member) | resource |
| [google_iam_workload_identity_pool.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool) | resource |
| [google_iam_workload_identity_pool_provider.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider) | resource |
| [google_organization_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/organization_iam_member) | resource |
| [google_project_iam_member.platform](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_service_account.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |
| [tfe_project.this](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/project) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_billing_account_id"></a> [billing\_account\_id](#input\_billing\_account\_id) | GCP billing account ID granted to the environment identity. | `string` | n/a | yes |
| <a name="input_folder_roles"></a> [folder\_roles](#input\_folder\_roles) | Roles the environment identity holds on its own folder; grants project creation inside it. | `list(string)` | n/a | yes |
| <a name="input_issuer"></a> [issuer](#input\_issuer) | OIDC issuer URI of the Terraform Cloud API endpoint. | `string` | n/a | yes |
| <a name="input_landing_project_id"></a> [landing\_project\_id](#input\_landing\_project\_id) | Project hosting the identity, pool, provider, and its bindings. | `string` | n/a | yes |
| <a name="input_landing_roles"></a> [landing\_roles](#input\_landing\_roles) | Roles the environment identity holds on the landing project. | `list(string)` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Environment name; every derived resource carries it. | `string` | n/a | yes |
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | GCP organisation ID hosting the platform. | `string` | n/a | yes |
| <a name="input_platform_roles"></a> [platform\_roles](#input\_platform\_roles) | Scoped role pairs for platform duties: organization, billing, or project:<id>. | <pre>list(object({<br/>    scope = string<br/>    role  = string<br/>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_google_folder"></a> [google\_folder](#output\_google\_folder) | The environment folder resource. |
| <a name="output_google_iam_workload_identity_pool"></a> [google\_iam\_workload\_identity\_pool](#output\_google\_iam\_workload\_identity\_pool) | The workload identity pool resource. |
| <a name="output_google_iam_workload_identity_pool_provider"></a> [google\_iam\_workload\_identity\_pool\_provider](#output\_google\_iam\_workload\_identity\_pool\_provider) | The workload identity pool provider resource. |
| <a name="output_google_service_account"></a> [google\_service\_account](#output\_google\_service\_account) | The environment service account resource. |
| <a name="output_tfe_project"></a> [tfe\_project](#output\_tfe\_project) | The TFC project resource. |
<!-- END_TF_DOCS -->
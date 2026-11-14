<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | >= 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_iam_workload_identity_pool_provider.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider) | resource |
| [google_service_account_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_attribute_condition"></a> [attribute\_condition](#input\_attribute\_condition) | CEL condition restricting which TFC tokens the provider accepts. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name stamped onto admitted tokens as attribute.environment. | `string` | n/a | yes |
| <a name="input_issuer"></a> [issuer](#input\_issuer) | OIDC issuer this provider trusts. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Provider id (tfc-<environment> convention). | `string` | n/a | yes |
| <a name="input_pool"></a> [pool](#input\_pool) | Workload identity pool id. | `string` | n/a | yes |
| <a name="input_pool_project_number"></a> [pool\_project\_number](#input\_pool\_project\_number) | Numeric project ID for principal URIs. | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | Project owning the pool. | `string` | n/a | yes |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | Service account this identity authenticates as. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_google_iam_workload_identity_pool_provider"></a> [google\_iam\_workload\_identity\_pool\_provider](#output\_google\_iam\_workload\_identity\_pool\_provider) | The OIDC provider resource. |
| <a name="output_google_service_account_iam_member"></a> [google\_service\_account\_iam\_member](#output\_google\_service\_account\_iam\_member) | SA IAM binding for workload identity. |
<!-- END_TF_DOCS -->
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
| [google_billing_account_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/billing_account_iam_member) | resource |
| [google_folder_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/folder_iam_member) | resource |
| [google_organization_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/organization_iam_member) | resource |
| [google_project_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_member"></a> [member](#input\_member) | Member, e.g. serviceAccount:<email>. | `string` | n/a | yes |
| <a name="input_role"></a> [role](#input\_role) | IAM role to bind. | `string` | n/a | yes |
| <a name="input_scope"></a> [scope](#input\_scope) | Binding target as a resolved ancestor path: folders/<ID>, projects/<id>, organizations/<ID>, or billingAccounts/<ID>. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_google_billing_account_iam_member"></a> [google\_billing\_account\_iam\_member](#output\_google\_billing\_account\_iam\_member) | Billing account IAM bindings. |
| <a name="output_google_folder_iam_member"></a> [google\_folder\_iam\_member](#output\_google\_folder\_iam\_member) | Folder IAM bindings. |
| <a name="output_google_organization_iam_member"></a> [google\_organization\_iam\_member](#output\_google\_organization\_iam\_member) | Organization IAM bindings. |
| <a name="output_google_project_iam_member"></a> [google\_project\_iam\_member](#output\_google\_project\_iam\_member) | Project IAM bindings. |
<!-- END_TF_DOCS -->
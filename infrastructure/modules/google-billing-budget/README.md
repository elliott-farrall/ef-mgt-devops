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
| [google_billing_budget.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/billing_budget) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_amount"></a> [amount](#input\_amount) | Monthly spend alert threshold in whole GBP. | `number` | n/a | yes |
| <a name="input_billing_account_id"></a> [billing\_account\_id](#input\_billing\_account\_id) | Billing account ID the budget belongs to. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Budget display name. | `string` | n/a | yes |
| <a name="input_scope"></a> [scope](#input\_scope) | Budget coverage: empty for the whole account, or a resolved ancestor path — projects/<id>, folders/<ID>, organizations/<ID>. | `string` | `""` | no |
| <a name="input_thresholds"></a> [thresholds](#input\_thresholds) | Alert fractions of the amount. | `list(number)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_google_billing_budget"></a> [google\_billing\_budget](#output\_google\_billing\_budget) | The GCP billing budget resource. |
<!-- END_TF_DOCS -->
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
| [google_project.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project) | resource |
| [google_project_service.apis](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_billing_account_id"></a> [billing\_account\_id](#input\_billing\_account\_id) | Billing account to attach. | `string` | n/a | yes |
| <a name="input_folder_id"></a> [folder\_id](#input\_folder\_id) | Numeric parent folder ID from module.google-folder. | `string` | n/a | yes |
| <a name="input_labels"></a> [labels](#input\_labels) | Mandatory label set. | `map(string)` | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | Project ID (globally unique). | `string` | n/a | yes |
| <a name="input_services"></a> [services](#input\_services) | List of GCP APIs to enable for this project. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_google_project"></a> [google\_project](#output\_google\_project) | The GCP project resource. |
| <a name="output_google_project_service"></a> [google\_project\_service](#output\_google\_project\_service) | Map of enabled GCP APIs keyed by service name. |
<!-- END_TF_DOCS -->
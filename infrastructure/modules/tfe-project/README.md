<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_tfe"></a> [tfe](#requirement\_tfe) | >= 0.60 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_tfe"></a> [tfe](#provider\_tfe) | >= 0.60 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [tfe_project.this](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/project) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_name"></a> [name](#input\_name) | TFC project name. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_tfe_project"></a> [tfe\_project](#output\_tfe\_project) | The TFE project resource. |
<!-- END_TF_DOCS -->
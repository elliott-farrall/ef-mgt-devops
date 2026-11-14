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
| [google_folder.tree](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/folder) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_tree"></a> [tree](#input\_tree) | The whole folder tree: organisation root resource name plus flat nodes keyed by name with their parent (root marks organisation-root children). | <pre>object({<br/>    root_parent = string<br/>    folders = map(object({<br/>      parent = string<br/>    }))<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_google_folder"></a> [google\_folder](#output\_google\_folder) | Maps of GCP folder resources. |
<!-- END_TF_DOCS -->
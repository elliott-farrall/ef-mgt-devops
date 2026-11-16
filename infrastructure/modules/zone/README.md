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
| [google_dns_managed_zone.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_managed_zone) | resource |
| [google_dns_record_set.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_domain"></a> [domain](#input\_domain) | DNS domain, e.g. elliott-farrall.phd. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Managed zone resource name. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project hosting the zone. | `string` | n/a | yes |
| <a name="input_records"></a> [records](#input\_records) | Platform-owned record sets: { name, type, ttl, records }. | <pre>list(object({<br/>    name    = string<br/>    type    = string<br/>    ttl     = number<br/>    records = list(string)<br/>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_google_dns_managed_zone"></a> [google\_dns\_managed\_zone](#output\_google\_dns\_managed\_zone) | The managed zone resource. |
| <a name="output_google_dns_record_set"></a> [google\_dns\_record\_set](#output\_google\_dns\_record\_set) | DNS records within the zone. |
<!-- END_TF_DOCS -->
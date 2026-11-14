<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_github"></a> [github](#requirement\_github) | >= 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_github"></a> [github](#provider\_github) | >= 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [github_branch_protection.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/branch_protection) | resource |
| [github_repository.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_protection"></a> [protection](#input\_protection) | Main-branch protection policy from locals, defaults merged. | <pre>object({<br/>    pattern                         = string<br/>    enforce_admins                  = bool<br/>    allows_force_pushes             = bool<br/>    allows_deletions                = bool<br/>    require_conversation_resolution = bool<br/>    required_linear_history         = bool<br/>    required_approving_review_count = number<br/>    dismiss_stale_reviews           = bool<br/>    strict_status_checks            = bool<br/>    status_checks                   = list(string)<br/>  })</pre> | n/a | yes |
| <a name="input_repository"></a> [repository](#input\_repository) | Repository settings from locals, defaults merged. | <pre>object({<br/>    name                   = string<br/>    description            = string<br/>    visibility             = string<br/>    has_issues             = bool<br/>    has_projects           = bool<br/>    has_wiki               = bool<br/>    allow_merge_commit     = bool<br/>    allow_squash_merge     = bool<br/>    allow_rebase_merge     = bool<br/>    allow_auto_merge       = bool<br/>    delete_branch_on_merge = bool<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_github_branch_protection"></a> [github\_branch\_protection](#output\_github\_branch\_protection) | Main branch protection policy. |
| <a name="output_github_repository"></a> [github\_repository](#output\_github\_repository) | The repository resource. |
<!-- END_TF_DOCS -->
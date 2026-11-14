# The only top-level variable. No default: omitting it is an error, by design.
variable "environment" {
  type        = string
  description = "Environment slot selecting environments/<name>/ YAML inputs, naming, labels, and policy."

  validation {
    condition     = contains(["mgt", "hub", "dev", "pre", "prd"], var.environment)
    error_message = "environment must be one of: mgt, hub, dev, pre, prd."
  }

  validation {
    condition     = fileexists("${path.root}/../environments/${var.environment}")
    error_message = "No environments/${var.environment}/ directory exists in this repository."
  }
}

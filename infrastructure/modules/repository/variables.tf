variable "status_checks" {
  description = "Required status checks for main: the CI checks plus one TFC predictive check per workspace building this repository."
  type        = list(string)
}

variable "pages" {
  description = "Whether the repository hosts a docs site built by the docs workflow."
  type        = bool
  default     = false
}

variable "repo" {
  description = "GitHub repository name."
  type        = string
}

variable "description" {
  description = "Repository description; defaults to the repository name."
  type        = string
  default     = null
}

variable "settings" {
  description = "Overrides for github_repository platform defaults."
  type        = any
  default     = {}
}

variable "protection" {
  description = "Overrides for the main-branch protection platform defaults."
  type        = any
  default     = {}
}

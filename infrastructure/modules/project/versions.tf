terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = ">= 0.84"
    }
    github = {
      source  = "integrations/github"
      version = ">= 6.0"
    }
  }
}

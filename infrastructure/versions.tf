terraform {
  required_version = ">= 1.9.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.11.0"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = "0.84.0"
    }
    github = {
      source  = "integrations/github"
      version = "6.13.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.29.0"
    }
  }
}

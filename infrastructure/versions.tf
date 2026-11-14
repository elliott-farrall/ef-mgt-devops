terraform {
  required_version = ">= 1.9.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = ">= 0.60"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.50"
    }
  }
}

terraform {
  required_version = ">= 1.9"

  required_providers {
    # Version 5 is a provider rewritten from scratch, generated from the Cloudflare API. Resource
    # names and field shapes differ from version 4, so guides from before 2025 usually do not
    # fit — see docs/edge/guide/.
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.25"
    }
  }
}

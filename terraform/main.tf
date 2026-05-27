# --- Provider configuration (Phase 2) ---
# This is the real project root module. Every .tf file in this directory is
# read together as one config; we split by concern (main / network / compute).

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1" # Frankfurt. Hardcoded for now — becomes a variable in Step 4.
}

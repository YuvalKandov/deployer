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
  region = var.aws_region
}

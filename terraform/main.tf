# --- Provider configuration (Phase 2) ---
# This is the real project root module. Every .tf file in this directory is
# read together as one config; we split by concern (main / network / compute).

terraform {
  required_version = ">= 1.10" # use_lockfile (native S3 state locking) needs 1.10+

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state in the S3 bucket created by ./bootstrap. This is what makes the
  # state shareable (one source of truth) instead of trapped on one laptop.
  #
  # GOTCHA: the backend block is read during `terraform init`, BEFORE variables
  # are evaluated — so it CANNOT use var.* or any interpolation. Every value
  # here must be a hardcoded literal. That's why the bucket name is pasted in by
  # hand from the bootstrap output, not referenced as a variable.
  backend "s3" {
    bucket       = "deployer-tfstate-056743698471"
    key          = "deployer/terraform.tfstate" # path of the state object inside the bucket
    region       = "eu-central-1"
    encrypt      = true # encrypt the state object at rest
    use_lockfile = true # native S3 locking — no DynamoDB table needed (TF 1.10+)
  }
}

provider "aws" {
  region = var.aws_region
}

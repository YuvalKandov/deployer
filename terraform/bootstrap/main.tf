# --- State backend bootstrap (Phase 2, Step 5) ---
# The chicken-and-egg: the main config wants to keep its state in S3, but you
# can't put state in a bucket that doesn't exist yet — and the bucket is created
# BY Terraform, whose state needs... a bucket. We break the cycle with a tiny,
# SEPARATE root module that creates only the bucket, using its OWN local state.
#
# This is the one piece of infra that can't sit behind the remote backend it
# provisions. You run it ONCE, up front, then point the main config at the
# bucket it outputs. (Terraform does NOT recurse into subdirectories, so this
# bootstrap/ folder is its own independent root module, not part of the main
# config one level up.)

terraform {
  required_version = ">= 1.10" # native S3 state locking (use_lockfile) needs 1.10+

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # NOTE: no `backend` block here on purpose. This module keeps LOCAL state
  # (terraform.tfstate on disk). That's fine — it manages exactly one bucket,
  # rarely changes, and gitignore already keeps the state file out of the repo.
}

provider "aws" {
  region = var.aws_region
}

# "Who am I?" — used to build a globally-unique bucket name from the account ID
# without hardcoding it. Same data-source-vs-resource idea as the Ubuntu AMI:
# a read-only lookup of something that already exists.
data "aws_caller_identity" "current" {}

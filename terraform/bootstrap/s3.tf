# The bucket that will store the MAIN config's terraform.tfstate.
#
# S3 bucket names are GLOBALLY unique across every AWS account on Earth, so we
# can't just call it "deployer-tfstate" — someone else may own it. Suffixing
# with our account ID guarantees uniqueness deterministically (no random name
# to remember) and ties the bucket clearly to this account.
resource "aws_s3_bucket" "state" {
  bucket = "deployer-tfstate-${data.aws_caller_identity.current.account_id}"

  # State is the crown jewels — lose it and Terraform forgets every resource it
  # manages. Refuse to let `terraform destroy` delete this bucket by accident.
  # To remove it ON PURPOSE: delete this lifecycle block first, then destroy.
  lifecycle {
    prevent_destroy = true
  }

  tags = { Name = "deployer-tfstate" }
}

# Versioning = an undo history for the state file. Every write keeps the prior
# version, so a corrupted or bad apply can be rolled back object-by-object.
# Non-negotiable for a state bucket.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt every object at rest. State frequently holds secrets in PLAINTEXT
# (passwords, keys, IPs), so server-side encryption is mandatory here.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # S3-managed keys; simplest. Could be aws:kms.
    }
  }
}

# Belt-and-suspenders: state must NEVER be publicly readable. Slam shut every
# public-access vector at the bucket level, so even a future bad bucket policy
# or ACL can't accidentally expose it.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy      = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

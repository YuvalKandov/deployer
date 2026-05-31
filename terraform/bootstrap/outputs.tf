# The bucket name to paste into the MAIN config's backend "s3" block.
# (The backend block can't read variables or outputs — see the note we'll add
# in main/main.tf — so you copy this literal value over by hand, once.)
output "state_bucket_name" {
  description = "Name of the S3 bucket holding remote state. Use in backend \"s3\" { bucket = ... }."
  value       = aws_s3_bucket.state.id
}

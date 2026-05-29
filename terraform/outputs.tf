# --- Outputs (Phase 2) ---
# Surface the handful of values you actually need after an apply, so you don't
# have to dig through the AWS console or parse `terraform show`. Outputs are
# also how OTHER tooling (the Phase 3 CI/CD deploy step) will read the server
# address programmatically: `terraform output -raw instance_public_ip`.

output "instance_public_ip" {
  description = "Static public IP (EIP) of the app server"
  value       = aws_eip.app.public_ip
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app.id
}

# A copy-paste-ready SSH command, built from the live IP. Saves you assembling
# it by hand and bakes in the right user (ubuntu) and key path.
output "ssh_command" {
  description = "Ready-to-use SSH command to reach the box"
  value       = "ssh -i ~/.ssh/deployer_key ubuntu@${aws_eip.app.public_ip}"
}

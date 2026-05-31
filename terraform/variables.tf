# --- Input variables (Phase 2, Step 4) ---
# Every value that might change between environments, or that is personal/
# sensitive, is declared here instead of being hardcoded in a resource block.
#
# A `variable` block only DECLARES the input (name, type, doc, optional default).
# The actual values arrive separately:
#   - if there's a `default`, that's used when nothing else is provided
#   - otherwise Terraform reads terraform.tfvars (gitignored) or prompts you
# This is the same split as CDK construct props: the prop is declared on the
# class; the value is passed when you instantiate the stack.

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-central-1" # Frankfurt
  
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC (the whole private address space)."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet (a slice of the VPC)."
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "AZ to pin the public subnet to. Must belong to aws_region."
  type        = string
  default     = "eu-central-1a"
}

variable "instance_type" {
  description = "EC2 instance size. t3.micro is the cheap burstable default."
  type        = string
  default     = "t3.micro"
}

variable "ssh_public_key_path" {
  description = "Path to the PUBLIC half of your SSH keypair, uploaded to AWS."
  type        = string
  default     = "~/.ssh/deployer_key.pub"
}

# No default ON PURPOSE. This is your personal IP and it changes, so we never
# bake a value into version-controlled code. Terraform will read it from
# terraform.tfvars (gitignored) — and error loudly if it's missing, which is
# exactly what we want for a security-critical input.
variable "my_ip_cidr" {
  description = "Your IP in CIDR form (e.g. 203.0.113.7/32). Guards SSH + admin UIs."
  type        = string

  validation {
    # Cheap guardrail: must look like a single host (/32). Stops a fat-fingered
    # /0 or /24 from silently re-opening SSH to a whole network.
    condition     = can(regex("/32$", var.my_ip_cidr))
    error_message = "my_ip_cidr must be a single host ending in /32 (e.g. 203.0.113.7/32)."
  }
}

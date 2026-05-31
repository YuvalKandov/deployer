# --- Compute layer (Phase 2, Step 3) ---
# The actual machine. We drop a single EC2 instance into the public subnet
# from network.tf, wrap it in the security group, give it a stable public
# address (Elastic IP), and hand it a boot script that installs Docker.
#
# THIS IS THE FILE THAT COSTS MONEY. A running t3.micro and an attached EIP
# bill by the hour. `terraform destroy` when you're done for the day.

# 1. AMI data source — NOT a resource we create, but a LOOKUP of an existing
#    image AWS already publishes. Canonical (Ubuntu's company) rebuilds these
#    constantly with security patches, so hardcoding an "ami-xxxx" ID would go
#    stale. Instead we query for "the most recent Ubuntu 22.04 amd64 image."
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's official AWS account ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 2. Key pair — upload the PUBLIC half of the keypair you generated with
#    ssh-keygen. AWS bakes this into the instance at boot so your matching
#    private key can authenticate. The private key never comes here.
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file(var.ssh_public_key_path) # read from disk at plan time
}

# 3. The EC2 instance itself — a worker placed in the public subnet.
resource "aws_instance" "app" {
  ami           = data.aws_ami.ubuntu.id # <-- reference => "resolve the AMI lookup first"
  instance_type = var.instance_type      # Nitro, 2 vCPU, burstable (see variables.tf)

  subnet_id              = aws_subnet.public.id           # which room it sits in
  vpc_security_group_ids = [aws_security_group.web.id]    # its personal firewall
  key_name               = aws_key_pair.deployer.key_name # which key can SSH in

  # Boot script. Terraform reads the file and passes it as cloud-init data;
  # the instance runs it ONCE on first boot, as root, before you ever log in.
  user_data = file("${path.module}/user-data.sh")

  # Replace the instance if the boot script changes, instead of ignoring it.
  user_data_replace_on_change = true

  tags = { Name = "deployer-app" }
}

# 4. Elastic IP — a STATIC public IP we own and attach to the instance.
#    A plain instance gets a public IP that CHANGES every stop/start. An EIP
#    stays fixed, so DNS / your SSH config / the CI deploy step keep working
#    across reboots. Caveat: an EIP that's NOT attached to a running instance
#    is billed (AWS charges for idle addresses) — another reason to destroy.
resource "aws_eip" "app" {
  instance = aws_instance.app.id
  domain   = "vpc"

  tags = { Name = "deployer-eip" }
}

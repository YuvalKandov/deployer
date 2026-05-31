# --- Networking layer (Phase 2, Step 2) ---
# A minimal PUBLIC VPC: one subnet reachable from the internet, with a
# firewall that opens only the ports our stack actually serves.
#
# Build order is NOT declared by us — Terraform infers it from the references
# between these resources (see aws_vpc.main.id used below). That dependency
# graph is the whole trick.

# 1. The VPC — an isolated virtual network. Everything else lives inside it.
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr # 65,536 private IPs to carve subnets from
  enable_dns_support   = true
  enable_dns_hostnames = true # needed for the EC2 instance to get a public DNS name

  tags = { Name = "deployer-vpc" }
}

# 2. Public subnet — one slice of the VPC's range, pinned to a single AZ.
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id        # <-- reference => "build the VPC first"
  cidr_block              = var.public_subnet_cidr # 256 IPs inside the VPC range
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true # instances here get a public IP automatically

  tags = { Name = "deployer-public-subnet" }
}

# 3. Internet Gateway — the VPC's single door to the public internet.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "deployer-igw" }
}

# 4. Route table — a rule sheet: "anything not local (0.0.0.0/0) goes to the IGW."
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"                  # all non-VPC-internal traffic...
    gateway_id = aws_internet_gateway.main.id # ...exits via the internet gateway
  }

  tags = { Name = "deployer-public-rt" }
}

# 5. Association — bind the route table to the subnet. THIS is what actually
#    makes the subnet "public"; without it, the IGW route doesn't apply.
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# 6. Security group — a STATEFUL firewall wrapped around the EC2 instance.
#    Stateful = if traffic is allowed IN, its reply is automatically allowed
#    OUT (and vice-versa). No need to mirror rules for return traffic.
resource "aws_security_group" "web" {
  name        = "deployer-sg"
  description = "Allow SSH and app/monitoring ports"
  vpc_id      = aws_vpc.main.id

  # --- Admin / shell access: locked to a single operator IP ---
  # SSH and the monitoring UIs are management surfaces. They expose a login
  # prompt, internal metrics, and dashboards with their own (un-hardened) auth.
  # No reason the whole internet should reach them, so they're scoped to my IP.

  ingress {
    description = "SSH (operator only)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr] # least privilege: one host, not 0.0.0.0/0
  }

  ingress {
    description = "Grafana (admin UI, operator only)"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "Prometheus (admin UI, operator only)"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  # --- Public app surface: meant to be seen by anyone (recruiters, demo) ---

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Flask app"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 = any protocol
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "deployer-sg" }
}

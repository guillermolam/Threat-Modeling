# ---------------------------------------------------------------------------
# Module: compute-tier — the SSRF surface (04 §4.16b), finding F-13
#
# This tier is the seven-version structural blind spot. Every earlier DFD
# jumped from "internet" straight to "S3", so the compute tier that HOLDS AN
# IAM ROLE ABLE TO READ THE BUCKET was never drawn — and the entire
# credential-theft class had nowhere to live.
#
# The attack, in four steps (04 §4.16b):
#   1. crafted input: URL / SSRF payload
#   2. server-side fetch to 169.254.169.254/latest/meta-data/iam/security-credentials/
#   3. IMDS returns temporary credentials
#   4. GetObject with stolen credentials — now a legitimate-looking API call
#
# The controls live HERE, not on the bucket policy. A perfect bucket policy
# does nothing against a stolen role.
# ---------------------------------------------------------------------------

data "aws_ami" "app" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = [var.ami_name_filter]
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags                 = merge(var.tags, { Name = "${var.name_prefix}-vpc" })
}

resource "aws_subnet" "app" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone = "${var.aws_region}a"
  tags              = merge(var.tags, { Name = "${var.name_prefix}-app-subnet" })
}

# ---------------------------------------------------------------------------
# F-13 mitigation · "block egress to 169.254.169.254 and link-local ranges
# from the app tier."
#
# Security groups cannot express a Deny, so the link-local block belongs in a
# NACL. Note the honest limit: a NACL stops the packet leaving the subnet, but
# IMDS is reached from the instance ITSELF over a link-local address that never
# crosses the subnet boundary — so the NACL is defence in depth for the
# outbound-proxy variant, and IMDSv2 + hop limit 1 is the control that actually
# bites. Both are configured; only one of them is load-bearing.
# ---------------------------------------------------------------------------
resource "aws_network_acl" "app" {
  count = var.block_link_local_egress ? 1 : 0

  vpc_id     = aws_vpc.this.id
  subnet_ids = [aws_subnet.app.id]

  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "deny"
    cidr_block = "169.254.0.0/16"
    from_port  = 0
    to_port    = 0
  }

  egress {
    rule_no    = 200
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  ingress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-app-nacl"
    Finding = "F-13"
  })
}

resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-app"
  description = "Application compute tier - the SSRF sink (04 4.16b)"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from the edge"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound - user-controlled URL fetches form the SSRF vector"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-app" })
}

# ---------------------------------------------------------------------------
# The instance.
#
# 04 §4.16b: "IMDSv1 = no defence; IMDSv2 requires a session token (PUT) and a
# hop limit that stops a proxied single GET."
#
#   http_tokens          = "optional" -> IMDSv1 still answers. F-13 wide open.
#   http_tokens          = "required" -> IMDSv2 only.
#   http_put_response_hop_limit = 1   -> a proxied request cannot reach IMDS.
# ---------------------------------------------------------------------------
resource "aws_instance" "app" {
  ami                    = data.aws_ami.app.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.app.id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = var.instance_profile_name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = var.imdsv2_required ? "required" : "optional"
    http_put_response_hop_limit = var.metadata_hop_limit
    instance_metadata_tags      = "disabled"
  }

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-app"
    Finding = "F-13"
    Actor   = "A-10 Compromised Compute Role"
  })
}

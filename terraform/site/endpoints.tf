# ---------------------------------------------------------------
# Private phone lines (interface VPC endpoints) so the app tier
# can reach Secrets Manager, Parameter Store and Session Manager
# without any internet route. Interview mode only.
# ---------------------------------------------------------------

locals {
  tt_interface_endpoints = var.enable_three_tier ? toset([
    "secretsmanager",
    "ssm",
    "ssmmessages",
    "ec2messages",
  ]) : toset([])
}

# Door on the phone lines: only the app may dial in
resource "aws_security_group" "endpoints" {
  count       = local.three_tier
  name        = "cloud-portfolio-${var.environment}-endpoints-sg"
  description = "Interface endpoints: HTTPS from the app only"
  vpc_id      = aws_vpc.three_tier[0].id

  tags = { Name = "cloud-portfolio-${var.environment}-endpoints-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_from_app" {
  count                        = local.three_tier
  security_group_id            = aws_security_group.endpoints[0].id
  description                  = "HTTPS from the app tier"
  referenced_security_group_id = aws_security_group.app[0].id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_vpc_security_group_egress_rule" "endpoints_all" {
  count             = local.three_tier
  security_group_id = aws_security_group.endpoints[0].id
  description       = "All outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# The phone lines themselves
resource "aws_vpc_endpoint" "interface" {
  for_each            = local.tt_interface_endpoints
  vpc_id              = aws_vpc.three_tier[0].id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.app[*].id
  security_group_ids  = [aws_security_group.endpoints[0].id]
  private_dns_enabled = true

  tags = { Name = "cloud-portfolio-${var.environment}-${each.key}-endpoint" }
}

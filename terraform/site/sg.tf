# ---------------------------------------------------------------
# Three-tier security groups: each tier only accepts traffic
# from the tier directly in front of it. Egress is open (-1);
# the private tiers have no internet route, so routing limits them.
# ---------------------------------------------------------------

locals {
  tt_app_port = 8080
  tt_db_port  = 5432
}

# AWS-maintained list of CloudFront's origin-facing IP ranges
data "aws_ec2_managed_prefix_list" "cloudfront" {
  count = local.three_tier
  name  = "com.amazonaws.global.cloudfront.origin-facing"
}

# --- Doors ------------------------------------------------------

resource "aws_security_group" "alb" {
  count       = local.three_tier
  name        = "cloud-portfolio-${var.environment}-alb-sg"
  description = "ALB: HTTPS from CloudFront only"
  vpc_id      = aws_vpc.three_tier[0].id

  tags = { Name = "cloud-portfolio-${var.environment}-alb-sg" }
}

resource "aws_security_group" "app" {
  count       = local.three_tier
  name        = "cloud-portfolio-${var.environment}-app-sg"
  description = "App: traffic from the ALB only"
  vpc_id      = aws_vpc.three_tier[0].id

  tags = { Name = "cloud-portfolio-${var.environment}-app-sg" }
}

resource "aws_security_group" "db" {
  count       = local.three_tier
  name        = "cloud-portfolio-${var.environment}-db-sg"
  description = "DB: Postgres from the app only"
  vpc_id      = aws_vpc.three_tier[0].id

  tags = { Name = "cloud-portfolio-${var.environment}-db-sg" }
}

# --- Ingress (who may knock) ------------------------------------

resource "aws_vpc_security_group_ingress_rule" "alb_from_cloudfront" {
  count             = local.three_tier
  security_group_id = aws_security_group.alb[0].id
  description       = "HTTPS from CloudFront origin-facing ranges"
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront[0].id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  count                        = local.three_tier
  security_group_id            = aws_security_group.app[0].id
  description                  = "App port from the ALB"
  referenced_security_group_id = aws_security_group.alb[0].id
  ip_protocol                  = "tcp"
  from_port                    = local.tt_app_port
  to_port                      = local.tt_app_port
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  count                        = local.three_tier
  security_group_id            = aws_security_group.db[0].id
  description                  = "Postgres from the app only"
  referenced_security_group_id = aws_security_group.app[0].id
  ip_protocol                  = "tcp"
  from_port                    = local.tt_db_port
  to_port                      = local.tt_db_port
}

# --- Egress (all protocols, anywhere) ---------------------------

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  count             = local.three_tier
  security_group_id = aws_security_group.alb[0].id
  description       = "All outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  count             = local.three_tier
  security_group_id = aws_security_group.app[0].id
  description       = "All outbound (no internet route from app subnets)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "db_all" {
  count             = local.three_tier
  security_group_id = aws_security_group.db[0].id
  description       = "All outbound (no internet route from data subnets)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------------------------------------------------------------
# Presentation tier (dynamic side): ALB that only answers
# CloudFront. Two locks: the CloudFront prefix list (sg.tf) and
# a secret header that CloudFront adds (cloudfront.tf).
# Interview mode only.
# ---------------------------------------------------------------

locals {
  tt_origin_name   = "origin-${var.environment}.${var.zone_name}"
  tt_origin_header = "X-Origin-Verify"
}

# The password CloudFront whispers at the window
resource "random_password" "origin_header" {
  count   = local.three_tier
  length  = 40
  special = false
}

# --- The truck's ID card (certificate) -------------------------

resource "aws_acm_certificate" "origin" {
  count             = local.three_tier
  domain_name       = local.tt_origin_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "origin_cert_validation" {
  for_each = {
    for dvo in flatten([for c in aws_acm_certificate.origin : c.domain_validation_options]) :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id         = data.aws_route53_zone.site.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 300
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "origin" {
  count                   = local.three_tier
  certificate_arn         = aws_acm_certificate.origin[0].arn
  validation_record_fqdns = [for r in aws_route53_record.origin_cert_validation : r.fqdn]
}

# --- The truck window (ALB) ------------------------------------

resource "aws_lb" "app" {
  count                      = local.three_tier
  name                       = "cloud-portfolio-${var.environment}-alb"
  load_balancer_type         = "application"
  internal                   = false
  subnets                    = aws_subnet.public[*].id
  security_groups            = [aws_security_group.alb[0].id]
  drop_invalid_header_fields = true
  enable_deletion_protection = false

  tags = { Name = "cloud-portfolio-${var.environment}-alb" }
}

# The kitchen door
resource "aws_lb_target_group" "app" {
  count       = local.three_tier
  name        = "cloud-portfolio-${var.environment}-app-tg"
  port        = local.tt_app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.three_tier[0].id
  target_type = "instance"

  health_check {
    path                = "/api/health"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = { Name = "cloud-portfolio-${var.environment}-app-tg" }
}

resource "aws_lb_target_group_attachment" "app" {
  count            = local.three_tier
  target_group_arn = aws_lb_target_group.app[0].arn
  target_id        = aws_instance.app[0].id
  port             = local.tt_app_port
}

# HTTPS only. Default answer is 403 unless a rule below matches.
resource "aws_lb_listener" "https" {
  count             = local.three_tier
  load_balancer_arn = aws_lb.app[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.origin[0].certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
    }
  }
}

# Right password AND /api/* -> kitchen
resource "aws_lb_listener_rule" "from_cloudfront" {
  count        = local.three_tier
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 10

  condition {
    http_header {
      http_header_name = local.tt_origin_header
      values           = [random_password.origin_header[0].result]
    }
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app[0].arn
  }
}

# --- The license plate (DNS) -----------------------------------

resource "aws_route53_record" "origin" {
  count   = local.three_tier
  zone_id = data.aws_route53_zone.site.zone_id
  name    = local.tt_origin_name
  type    = "A"

  alias {
    name                   = aws_lb.app[0].dns_name
    zone_id                = aws_lb.app[0].zone_id
    evaluate_target_health = true
  }
}

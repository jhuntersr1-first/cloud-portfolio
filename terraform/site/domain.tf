# The domain's DNS "phone book" (created when the domain was registered)
data "aws_route53_zone" "site" {
  name = var.zone_name
}

# The ID card proving this site really is these names (CloudFront requires us-east-1)
resource "aws_acm_certificate" "site" {
  domain_name               = var.domain_names[0]
  subject_alternative_names = slice(var.domain_names, 1, length(var.domain_names))
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Proof-of-ownership notes AWS asks us to place in DNS
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
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

# Wait until AWS has read the notes and approved the ID card
resource "aws_acm_certificate_validation" "site" {
  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Phone-book entries: each name points at this environment's CloudFront (IPv4)
resource "aws_route53_record" "site_ipv4" {
  for_each = toset(var.domain_names)

  zone_id = data.aws_route53_zone.site.zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

# Same, for IPv6 (the distribution has IPv6 turned on)
resource "aws_route53_record" "site_ipv6" {
  for_each = toset(var.domain_names)

  zone_id = data.aws_route53_zone.site.zone_id
  name    = each.value
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

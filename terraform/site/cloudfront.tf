

# CloudFront's ID badge for entering the private S3 bucket
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "cloud-portfolio-${var.environment}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# The doorman: only lets in visitors who came through our real address(es).
# Anyone using the raw *.cloudfront.net side door gets a 403.
resource "aws_cloudfront_function" "host_guard" {
  name    = "cloud-portfolio-${var.environment}-host-guard"
  runtime = "cloudfront-js-2.0"
  comment = "Block requests not addressed to ${var.environment}'s custom domain"
  publish = true

  code = <<-EOT
    function handler(event) {
      var allowed = ${jsonencode(var.domain_names)};
      var hostHeader = event.request.headers.host;
      var host = hostHeader ? hostHeader.value.toLowerCase() : "";
      if (allowed.indexOf(host) === -1) {
        return { statusCode: 403, statusDescription: "Forbidden" };
      }
      return event.request;
    }
  EOT
}

# The front counter: serves the site worldwide over HTTPS
resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  comment             = "cloud-portfolio ${var.environment} site"
  aliases             = var.domain_names

  origin {
    origin_id                = "s3-site"
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  # Interview mode: the food truck (ALB) as a second origin
  dynamic "origin" {
    for_each = var.enable_three_tier ? [1] : []
    content {
      origin_id   = "alb-app"
      domain_name = aws_route53_record.origin[0].fqdn

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }

      # The password whispered at the truck window
      custom_header {
        name  = local.tt_origin_header
        value = random_password.origin_header[0].result
      }
    }
  }

  default_cache_behavior {
    target_origin_id           = "s3-site"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = aws_cloudfront_cache_policy.static.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.site.id


    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.host_guard.arn
    }
  }

  # Interview mode: /api/* goes to the truck, never cached
  dynamic "ordered_cache_behavior" {
    for_each = var.enable_three_tier ? [1] : []
    content {
      path_pattern               = "/api/*"
      target_origin_id           = "alb-app"
      viewer_protocol_policy     = "redirect-to-https"
      allowed_methods            = ["GET", "HEAD"]
      cached_methods             = ["GET", "HEAD"]
      compress                   = true
      cache_policy_id            = data.aws_cloudfront_cache_policy.no_cache[0].id
      origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.api[0].id
      response_headers_policy_id = aws_cloudfront_response_headers_policy.site.id

      function_association {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.host_guard.arn
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# The storage room's door rule: only THIS CloudFront may read files, and only over HTTPS
resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontRead"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.site.arn}/*"
        Condition = { StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.site.arn } }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.site.arn, "${aws_s3_bucket.site.arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.site]
}

output "site_url" {
  value = "https://${var.domain_names[0]}"
}

output "site_bucket_name" {
  value = aws_s3_bucket.site.bucket
}

output "distribution_id" {
  value = aws_cloudfront_distribution.site.id
}

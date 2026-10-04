# Response headers policy: security headers, a strict CSP, browser caching,
# and removal of headers that reveal how the site is built
resource "aws_cloudfront_response_headers_policy" "site" {
  name    = "cloud-portfolio-${var.environment}-headers"
  comment = "Security headers + CSP + strip origin fingerprints"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    # Modern guidance: turn the old XSS filter OFF (sends "X-XSS-Protection: 0"); the CSP does this job now
    xss_protection {
      protection = false
      override   = true
    }

    content_security_policy {
      content_security_policy = "default-src 'none'; style-src 'self' 'unsafe-inline'; img-src 'self'; font-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'; upgrade-insecure-requests"
      override                = true
    }
  }

  custom_headers_config {
    # The page never needs a camera, microphone, or location
    items {
      header   = "Permissions-Policy"
      value    = "camera=(), microphone=(), geolocation=()"
      override = true
    }

    # Browsers may reuse their copy for 5 minutes, then check for a newer one
    items {
      header   = "Cache-Control"
      value    = "public, max-age=300"
      override = true
    }
  }

  # Strip headers that tell outsiders what's behind CloudFront
  remove_headers_config {
    items {
      header = "Server"
    }
    items {
      header = "x-amz-server-side-encryption"
    }
    items {
      header = "x-amz-version-id"
    }
  }
}

# Cache policy for a static site (adapted from LAB2's static cache policy)
resource "aws_cloudfront_cache_policy" "static" {
  name        = "cloud-portfolio-${var.environment}-static"
  comment     = "Static site: cache aggressively, keep the cache key minimal"
  default_ttl = 86400    # 1 day
  max_ttl     = 31536000 # 1 year
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    # A static page never changes based on cookies, query strings, or headers
    cookies_config {
      cookie_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }

    # Store compressed copies so visitors download less
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true
  }
}

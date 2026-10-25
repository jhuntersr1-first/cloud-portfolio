# AWS-managed CloudFront policies for the /api/* path (interview mode only)

data "aws_cloudfront_cache_policy" "no_cache" {
  count = local.three_tier
  name  = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "api" {
  count = local.three_tier
  name  = "Managed-AllViewerExceptHostHeader"
}

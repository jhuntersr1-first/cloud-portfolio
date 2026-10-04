locals {
  state_bucket_arn = "arn:aws:s3:::cloud-portfolio-tfstate-bdd0b989"
}

data "aws_iam_policy_document" "pipeline" {
  for_each = local.environments

  # Terraform logbook: read/write ONLY this environment's state and lock file
  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [local.state_bucket_arn]
  }

  statement {
    sid     = "ReadWriteOwnState"
    actions = ["s3:GetObject", "s3:PutObject"]
    resources = [
      "${local.state_bucket_arn}/site/${each.key}/terraform.tfstate",
      "${local.state_bucket_arn}/site/${each.key}/terraform.tfstate.tflock",
    ]
  }

  statement {
    sid       = "ReleaseOwnLock"
    actions   = ["s3:DeleteObject"]
    resources = ["${local.state_bucket_arn}/site/${each.key}/terraform.tfstate.tflock"]
  }

  # Site bucket: full control, but ONLY buckets named for this environment
  statement {
    sid     = "ManageOwnSiteBucket"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::cloud-portfolio-${each.key}-site-*",
      "arn:aws:s3:::cloud-portfolio-${each.key}-site-*/*",
    ]
  }

  # CloudFront: has limited resource-level permission support, so these use "*".
  # Compensating controls: no IAM, explicit denies below, prod gated by approval.
  statement {
    sid = "ManageCloudFront"
    actions = [
      "cloudfront:Get*",
      "cloudfront:List*",
      "cloudfront:CreateDistribution",
      "cloudfront:UpdateDistribution",
      "cloudfront:DeleteDistribution",
      "cloudfront:TagResource",
      "cloudfront:UntagResource",
      "cloudfront:CreateOriginAccessControl",
      "cloudfront:UpdateOriginAccessControl",
      "cloudfront:DeleteOriginAccessControl",
      "cloudfront:CreateCachePolicy",
      "cloudfront:UpdateCachePolicy",
      "cloudfront:DeleteCachePolicy",
      "cloudfront:CreateResponseHeadersPolicy",
      "cloudfront:UpdateResponseHeadersPolicy",
      "cloudfront:DeleteResponseHeadersPolicy",
      "cloudfront:CreateInvalidation",
    ]
    resources = ["*"]
  }

  # Backstops: explicit denies win over any allow, anywhere
  statement {
    sid       = "DenyIdentityChanges"
    effect    = "Deny"
    actions   = ["iam:*", "organizations:*", "sso:*", "identitystore:*"]
    resources = ["*"]
  }

  statement {
    sid     = "DenyOtherLogbooks"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      "${local.state_bucket_arn}/identity/*",
      "${local.state_bucket_arn}/bootstrap/*",
    ]
  }
}

resource "aws_iam_role_policy" "pipeline" {
  for_each = local.environments

  name   = "site-${each.key}-pipeline"
  role   = aws_iam_role.pipeline[each.key].id
  policy = data.aws_iam_policy_document.pipeline[each.key].json
}

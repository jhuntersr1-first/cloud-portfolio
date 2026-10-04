# Pull requests may only PLAN: read state and read current settings, never change anything
data "aws_iam_policy_document" "plan_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.github_repo}:pull_request"]
    }
  }
}

resource "aws_iam_role" "plan" {
  name                 = "cloud-portfolio-plan-readonly"
  description          = "GitHub Actions on pull requests: terraform plan only (read-only)"
  assume_role_policy   = data.aws_iam_policy_document.plan_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "plan" {
  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [local.state_bucket_arn]
  }

  statement {
    sid       = "ReadSiteState"
    actions   = ["s3:GetObject"]
    resources = ["${local.state_bucket_arn}/site/*"]
  }

  statement {
    sid     = "ReadSiteBucketSettings"
    actions = ["s3:Get*", "s3:List*"]
    resources = [
      "arn:aws:s3:::cloud-portfolio-*-site-*",
      "arn:aws:s3:::cloud-portfolio-*-site-*/*",
    ]
  }

  statement {
    sid       = "ReadCloudFront"
    actions   = ["cloudfront:Get*", "cloudfront:List*"]
    resources = ["*"]
  }

  statement {
    sid       = "ReadCertificates"
    actions   = ["acm:DescribeCertificate", "acm:ListTagsForCertificate"]
    resources = ["arn:aws:acm:us-east-1:*:certificate/*"]
  }

  statement {
    sid       = "ListCertificates"
    actions   = ["acm:ListCertificates"]
    resources = ["*"]
  }

  statement {
    sid       = "ReadDnsZone"
    actions   = ["route53:GetHostedZone", "route53:ListResourceRecordSets", "route53:ListTagsForResource"]
    resources = [data.aws_route53_zone.site.arn]
  }

  statement {
    sid       = "FindZones"
    actions   = ["route53:ListHostedZones", "route53:ListHostedZonesByName", "route53:GetChange"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "plan" {
  name   = "terraform-plan-readonly"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan.json
}

output "pipeline_role_arns" {
  value = { for env, role in aws_iam_role.pipeline : env => role.arn }
}

output "plan_role_arn" {
  value = aws_iam_role.plan.arn
}

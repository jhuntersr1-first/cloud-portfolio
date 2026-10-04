locals {
  environments = toset(["dev", "test", "prod"])
}

# Each environment's role trusts ONLY GitHub jobs running in that GitHub Environment
data "aws_iam_policy_document" "env_trust" {
  for_each = local.environments

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
      values   = ["repo:${local.github_repo}:environment:${each.key}"]
    }
  }
}

resource "aws_iam_role" "pipeline" {
  for_each = local.environments

  name                 = "cloud-portfolio-${each.key}-pipeline"
  description          = "GitHub Actions: Terraform + content deploy for ${each.key} only (no IAM permissions)"
  assume_role_policy   = data.aws_iam_policy_document.env_trust[each.key].json
  max_session_duration = 3600
}

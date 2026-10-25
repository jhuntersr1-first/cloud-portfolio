# ---------------------------------------------------------------
# App tier badge: the EC2 instance can read ONLY its own DB secret
# and DB parameters, plus register with Session Manager.
# Interview mode only.
# ---------------------------------------------------------------

data "aws_caller_identity" "current" {}

# Who may wear the badge: EC2 only
data "aws_iam_policy_document" "app_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  count              = local.three_tier
  name               = "cloud-portfolio-${var.environment}-app-role"
  assume_role_policy = data.aws_iam_policy_document.app_assume.json

  tags = { Name = "cloud-portfolio-${var.environment}-app-role" }
}

# What the badge opens
data "aws_iam_policy_document" "app_access" {
  count = local.three_tier

  statement {
    sid       = "ReadDbSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_db_instance.counter[0].master_user_secret[0].secret_arn]
  }

  statement {
    sid     = "ReadDbParameters"
    actions = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/cloud-portfolio/${var.environment}/db/*"
    ]
  }
}

resource "aws_iam_role_policy" "app_access" {
  count  = local.three_tier
  name   = "read-own-db-config"
  role   = aws_iam_role.app[0].id
  policy = data.aws_iam_policy_document.app_access[0].json
}

# Session Manager: no SSH keys, no port 22
resource "aws_iam_role_policy_attachment" "app_ssm" {
  count      = local.three_tier
  role       = aws_iam_role.app[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# The clip that attaches the badge to the instance
resource "aws_iam_instance_profile" "app" {
  count = local.three_tier
  name  = "cloud-portfolio-${var.environment}-app-profile"
  role  = aws_iam_role.app[0].name
}

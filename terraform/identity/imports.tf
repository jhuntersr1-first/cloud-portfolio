# One-time adoption of resources previously managed by the site stack.
# Safe to delete this file after the first successful apply.

import {
  to = aws_iam_openid_connect_provider.github
  id = "arn:aws:iam::${var.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

import {
  to = aws_iam_role.github_deploy
  id = "cloud-portfolio-github-deploy"
}

import {
  to = aws_iam_role_policy.deploy
  id = "cloud-portfolio-github-deploy:site-content-deploy"
}

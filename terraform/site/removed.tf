# These moved to the identity stack. Forget them here, but DO NOT destroy them in AWS.
# Safe to delete this file after the next successful apply of this stack.

removed {
  from = aws_iam_openid_connect_provider.github
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_iam_role.github_deploy
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_iam_role_policy.deploy
  lifecycle {
    destroy = false
  }
}

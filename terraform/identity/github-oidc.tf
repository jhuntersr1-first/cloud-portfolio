locals {
  # GitHub's ID card includes immutable owner/repo IDs (protects against repojacking)
  github_repo = "jhuntersr1-first@246341035/cloud-portfolio@1400928325"
}

# Tell AWS to trust GitHub as an ID card issuer (used by every pipeline role)
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

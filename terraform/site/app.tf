# ---------------------------------------------------------------
# App tier: one small EC2 instance running the visitor counter.
# No public IP, no SSH key: reach it with Session Manager only.
# Interview mode only.
# ---------------------------------------------------------------

# Latest Amazon Linux 2023 (ARM) image, published by AWS
data "aws_ssm_parameter" "al2023_arm" {
  count = local.three_tier
  name  = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

resource "aws_instance" "app" {
  count                       = local.three_tier
  ami                         = data.aws_ssm_parameter.al2023_arm[0].insecure_value
  instance_type               = "t4g.micro"
  subnet_id                   = aws_subnet.app[0].id
  vpc_security_group_ids      = [aws_security_group.app[0].id]
  iam_instance_profile        = aws_iam_instance_profile.app[0].name
  associate_public_ip_address = false
  ebs_optimized               = true

  # IMDSv2 only: blocks the classic SSRF credential-theft trick
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  user_data = templatefile("${path.module}/app/user_data.sh.tftpl", {
    app_b64     = base64encode(file("${path.module}/app/counter.py"))
    environment = var.environment
    app_port    = local.tt_app_port
    region      = data.aws_region.current.region
  })
  user_data_replace_on_change = true

  # Boot script needs the S3 hallway (packages) and phone lines (config) ready first
  depends_on = [
    aws_vpc_endpoint.s3,
    aws_vpc_endpoint.interface,
    aws_route_table_association.app,
  ]

  tags = { Name = "cloud-portfolio-${var.environment}-app" }
}

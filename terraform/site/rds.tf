# ---------------------------------------------------------------
# Data tier: Postgres for the visitor counter (interview mode only).
# RDS creates and rotates the password in Secrets Manager itself,
# so it never appears in Terraform code or state.
# ---------------------------------------------------------------

resource "aws_db_subnet_group" "three_tier" {
  count       = local.three_tier
  name        = "cloud-portfolio-${var.environment}-db-subnets"
  description = "Data subnets for the visitor counter database"
  subnet_ids  = aws_subnet.data[*].id

  tags = { Name = "cloud-portfolio-${var.environment}-db-subnets" }
}

resource "aws_db_instance" "counter" {
  count      = local.three_tier
  identifier = "cloud-portfolio-${var.environment}-counter"

  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name                     = "counter"
  username                    = "counter_admin"
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.three_tier[0].name
  vpc_security_group_ids = [aws_security_group.db[0].id]
  publicly_accessible    = false
  multi_az               = false

  iam_database_authentication_enabled = true
  auto_minor_version_upgrade          = true
  copy_tags_to_snapshot               = true
  backup_retention_period             = 1

  # Interview mode: must tear down cleanly afterward
  deletion_protection = false
  skip_final_snapshot = true
  apply_immediately   = true

  tags = { Name = "cloud-portfolio-${var.environment}-counter" }
}

# --- Bulletin board (Parameter Store): where the pantry is ------

resource "aws_ssm_parameter" "db_host" {
  count = local.three_tier
  name  = "/cloud-portfolio/${var.environment}/db/host"
  type  = "String"
  value = aws_db_instance.counter[0].address
}

resource "aws_ssm_parameter" "db_port" {
  count = local.three_tier
  name  = "/cloud-portfolio/${var.environment}/db/port"
  type  = "String"
  value = tostring(aws_db_instance.counter[0].port)
}

resource "aws_ssm_parameter" "db_name" {
  count = local.three_tier
  name  = "/cloud-portfolio/${var.environment}/db/name"
  type  = "String"
  value = aws_db_instance.counter[0].db_name
}

# Points at the safe (the secret's ARN), not the key itself
resource "aws_ssm_parameter" "db_secret_arn" {
  count = local.three_tier
  name  = "/cloud-portfolio/${var.environment}/db/secret-arn"
  type  = "String"
  value = aws_db_instance.counter[0].master_user_secret[0].secret_arn
}

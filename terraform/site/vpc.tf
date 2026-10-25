# ---------------------------------------------------------------
# Three-tier network: only built when enable_three_tier = true
# (interview mode). The static site never depends on any of this.
# ---------------------------------------------------------------

locals {
  three_tier  = var.enable_three_tier ? 1 : 0
  tt_vpc_cidr = "10.190.0.0/24"
  tt_azs      = slice(data.aws_availability_zones.available.names, 0, 2)
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_region" "current" {}

# The building
resource "aws_vpc" "three_tier" {
  count                = local.three_tier
  cidr_block           = local.tt_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "cloud-portfolio-${var.environment}-vpc" }
}

# Lock the default security group so nothing accidentally uses it
resource "aws_default_security_group" "three_tier" {
  count  = local.three_tier
  vpc_id = aws_vpc.three_tier[0].id

  tags = { Name = "cloud-portfolio-${var.environment}-default-locked" }
}

# The front door to the internet (only public subnets use it)
resource "aws_internet_gateway" "three_tier" {
  count  = local.three_tier
  vpc_id = aws_vpc.three_tier[0].id

  tags = { Name = "cloud-portfolio-${var.environment}-igw" }
}

# --- Rooms -----------------------------------------------------

# Public: ALB only
resource "aws_subnet" "public" {
  count                   = var.enable_three_tier ? 2 : 0
  vpc_id                  = aws_vpc.three_tier[0].id
  cidr_block              = cidrsubnet(local.tt_vpc_cidr, 3, count.index)
  availability_zone       = local.tt_azs[count.index]
  map_public_ip_on_launch = false

  tags = { Name = "cloud-portfolio-${var.environment}-public-${count.index}" }
}

# App: EC2, no internet route
resource "aws_subnet" "app" {
  count             = var.enable_three_tier ? 2 : 0
  vpc_id            = aws_vpc.three_tier[0].id
  cidr_block        = cidrsubnet(local.tt_vpc_cidr, 3, 2 + count.index)
  availability_zone = local.tt_azs[count.index]

  tags = { Name = "cloud-portfolio-${var.environment}-app-${count.index}" }
}

# Data: RDS, no internet route
resource "aws_subnet" "data" {
  count             = var.enable_three_tier ? 2 : 0
  vpc_id            = aws_vpc.three_tier[0].id
  cidr_block        = cidrsubnet(local.tt_vpc_cidr, 3, 4 + count.index)
  availability_zone = local.tt_azs[count.index]

  tags = { Name = "cloud-portfolio-${var.environment}-data-${count.index}" }
}

# --- Hallways (route tables) ----------------------------------

resource "aws_route_table" "public" {
  count  = local.three_tier
  vpc_id = aws_vpc.three_tier[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.three_tier[0].id
  }

  tags = { Name = "cloud-portfolio-${var.environment}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = var.enable_three_tier ? 2 : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# Private rooms: no default route at all
resource "aws_route_table" "private" {
  count  = local.three_tier
  vpc_id = aws_vpc.three_tier[0].id

  tags = { Name = "cloud-portfolio-${var.environment}-private-rt" }
}

resource "aws_route_table_association" "app" {
  count          = var.enable_three_tier ? 2 : 0
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.private[0].id
}

resource "aws_route_table_association" "data" {
  count          = var.enable_three_tier ? 2 : 0
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.private[0].id
}

# Free private hallway to S3 (Amazon Linux package mirrors live there)
resource "aws_vpc_endpoint" "s3" {
  count             = local.three_tier
  vpc_id            = aws_vpc.three_tier[0].id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private[0].id]

  tags = { Name = "cloud-portfolio-${var.environment}-s3-endpoint" }
}

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Terraform's logbook lives in the encrypted, versioned vault
  backend "s3" {
    bucket       = "cloud-portfolio-tfstate-bdd0b989"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "cloud-portfolio"
      ManagedBy   = "terraform"
      Component   = "site"
      Environment = var.environment
    }
  }
}

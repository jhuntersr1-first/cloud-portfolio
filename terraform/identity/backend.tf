terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Identity has its OWN logbook, separate from every site environment
  backend "s3" {
    bucket       = "cloud-portfolio-tfstate-bdd0b989"
    key          = "identity/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project   = "cloud-portfolio"
      ManagedBy = "terraform"
      Component = "identity"
    }
  }
}

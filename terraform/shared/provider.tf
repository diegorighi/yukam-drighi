terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment para usar S3 backend (recomendado para produção)
  # backend "s3" {
  #   bucket = "vanessa-mudanca-terraform-state"
  #   key    = "shared/terraform.tfstate"
  #   region = "sa-east-1"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "va-nessa-mudanca"
      ManagedBy   = "Terraform"
      Layer       = "shared"
    }
  }
}

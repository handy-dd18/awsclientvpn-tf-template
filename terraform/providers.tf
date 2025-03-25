terraform {
  required_version = "~> 1.11.0" # Terraform 1.7.xを指定

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40.0" # AWS プロバイダーのバージョンも固定
    }
  }
}

provider "aws" {
  region = var.aws_region
}

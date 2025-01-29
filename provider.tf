terraform {
  required_version = "~> 1.10.0" # Allows 1.10.x but not 1.11.0
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.8.0" # Allows 5.8.x but not 5.9.0
    }
  }

  # Must init with s3 bucket name from environemnt variables at runtime
  # terraform init -backend-config="bucket=${TF_VAR_s3_bucket_name}"
  backend "s3" {
    key    = "dynamic-terraform.tfstate"
    region = "us-east-2"
    # dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region # Use variable instead of hardcoded region

  default_tags {
    tags = {
      Terraform = "true"
    }
  }
}

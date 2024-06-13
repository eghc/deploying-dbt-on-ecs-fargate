terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    key     = "ignite-data-terraform/terraform.tfstate"
    encrypt = true
    region = "us-west-2"
  }

}

# Configure the AWS Provider
provider "aws" {
  region = "us-west-2"
}
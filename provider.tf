terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region  = "us-west-2"
  profile = "monks-poc-admin-chrisl"

  default_tags {
    tags = {
      Project     = "vast-datalayer-poc"
      Environment = "poc"
      ManagedBy   = "terraform"
    }
  }
}
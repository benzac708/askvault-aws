terraform {
  required_version = "~> 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Local backend on purpose: this repo's contract is "the same apply works
  # against LocalStack and AWS". Remote state (S3 + DynamoDB locking) is the
  # one block a production run swaps in; nothing else changes.
}
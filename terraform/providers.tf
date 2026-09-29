provider "aws" {
  region = var.aws_region

  # LocalStack accepts any credentials; these are the conventional ones.
  access_key = "test"
  secret_key = "test"

  skip_credentials_validation = true
  skip_metadata_api_check     = true

  # LocalStack serves S3 via path-style addressing.
  s3_use_path_style = true

  # Every service pinned to one endpoint. The whole "LocalStack vs AWS"
  # difference is this block: delete it for a real account.
  endpoints {
    s3         = var.aws_endpoint
    ec2        = var.aws_endpoint
    ecs        = var.aws_endpoint
    elbv2      = var.aws_endpoint
    route53    = var.aws_endpoint
    iam        = var.aws_endpoint
    sts        = var.aws_endpoint
    dynamodb   = var.aws_endpoint
    sqs        = var.aws_endpoint
    logs       = var.aws_endpoint
    ssm        = var.aws_endpoint
    cloudwatch = var.aws_endpoint
    acm        = var.aws_endpoint
  }
}
# The ingest half of the estate: a versioned corpus bucket, a queue that
# decouples corpus events from processing, and a records table. The full
# S3 -> SQS -> Lambda -> DynamoDB pipeline lives in the aws-localstack repo;
# here it is the minimal surface the app deployment depends on.

resource "aws_s3_bucket" "corpus" {
  bucket        = var.corpus_bucket
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "corpus" {
  bucket = aws_s3_bucket.corpus.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_sqs_queue" "ingest" {
  name                       = var.ingest_queue
  visibility_timeout_seconds = 30
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.ingest_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue" "ingest_dlq" {
  name = "askvault-ingest-dlq"
}

resource "aws_dynamodb_table" "records" {
  name         = var.records_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}
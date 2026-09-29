# Two roles, both least-privilege and written as if IAM were enforced (the
# README is explicit that LocalStack does not enforce it -- the policies are
# the product, not the emulator).

data "aws_iam_policy_document" "ecs_execution_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecs_execution_permissions" {
  statement {
    sid       = "PullImage"
    actions   = ["ecr:GetAuthorizationToken", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
    resources = ["*"]
  }
  statement {
    sid       = "ShipLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.app.arn}:*"]
  }
  statement {
    sid       = "ReadSecret"
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.llm_key.arn]
  }
}

resource "aws_iam_role" "ecs_execution" {
  name               = "askvault-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_execution_assume.json
}

resource "aws_iam_role_policy" "ecs_execution" {
  name   = "execution-policy"
  role   = aws_iam_role.ecs_execution.id
  policy = data.aws_iam_policy_document.ecs_execution_permissions.json
}

# Task role: the app's runtime identity. It touches only the ingest surface
# and the log group -- nothing the app does not need.
data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecs_task_permissions" {
  statement {
    sid       = "ReadCorpus"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.corpus.arn}/*"]
  }
  statement {
    sid       = "WriteRecords"
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.records.arn]
  }
  statement {
    sid       = "SendQueue"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.ingest.arn]
  }
  statement {
    sid       = "ShipLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.app.arn}:*"]
  }
}

resource "aws_iam_role" "ecs_task" {
  name               = "askvault-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

resource "aws_iam_role_policy" "ecs_task" {
  name   = "task-policy"
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.ecs_task_permissions.json
}
output "app_url" {
  description = "Route53 front of the load balancer."
  value       = "http://${aws_route53_record.app.name}.${aws_route53_zone.app.name}"
}

output "cluster" {
  description = "ECS cluster name (empty while emulated - ECS is Pro-gated on LocalStack)."
  value       = var.emulated ? "" : aws_ecs_cluster.app[0].name
}

output "task_definition" {
  description = "Registered task definition family (empty while emulated)."
  value       = var.emulated ? "" : aws_ecs_task_definition.app[0].family
}

output "corpus_bucket" {
  value = aws_s3_bucket.corpus.id
}

output "records_table" {
  value = aws_dynamodb_table.records.name
}
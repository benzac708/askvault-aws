resource "aws_cloudwatch_log_group" "app" {
  name = "/ecs/askvault"
}

resource "aws_ecs_cluster" "app" {
  count = var.emulated ? 0 : 1
  name  = "askvault"
}

# The task is stateless by design: AskVault derives its SQLite index from the
# baked corpus at startup, so there is no volume, no EFS, and no multi-AZ
# storage dance. That is a real simplification, stated rather than implied.
resource "aws_ecs_task_definition" "app" {
  count                    = var.emulated ? 0 : 1
  family                   = "askvault"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name         = "askvault"
      image        = var.app_image
      essential    = true
      portMappings = [{ containerPort = 8000, protocol = "tcp" }]
      environment = [
        { name = "LLM_PROVIDER", value = "openrouter" },
        { name = "LLM_MODEL", value = "google/gemini-2.5-flash-lite" },
        { name = "LLM_BASE_URL", value = "https://openrouter.ai/api/v1" },
      ]
      # The credential is a parameter, not a literal: read from SSM at
      # runtime, mirroring the k8s Secret-vs-ConfigMap split in askvault-gitops.
      secrets = [
        { name = "LLM_API_KEY", valueFrom = aws_ssm_parameter.llm_key.name }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "askvault"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8000/healthz || exit 1"]
        interval    = 10
        timeout     = 5
        retries     = 3
        startPeriod = 15
      }
    }
  ])
}

resource "aws_ecs_service" "app" {
  count           = var.emulated ? 0 : 1
  name            = "askvault"
  cluster         = aws_ecs_cluster.app[0].id
  task_definition = aws_ecs_task_definition.app[0].arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = false
  }

  # NOTE: the ELBv2 wiring for this service lives on real AWS; LocalStack
  # community cannot create load balancers (see edge.tf).
}
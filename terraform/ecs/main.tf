# ============================================================================
# ECS Infrastructure for VaNessa Mudança Microservices
# ============================================================================
# This Terraform configuration creates:
# - ECR repositories for Docker images
# - ECS Fargate cluster
# - Application Load Balancer
# - ECS Services with auto-scaling
# - CloudWatch Log Groups
# - IAM Roles and Policies
# ============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment to use S3 backend for state management
  # backend "s3" {
  #   bucket = "vanessa-mudanca-terraform-state"
  #   key    = "ecs/terraform.tfstate"
  #   region = "sa-east-1"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "va-nessa-mudanca"
      ManagedBy   = "Terraform"
      Layer       = "ecs"
    }
  }
}

# ============================================================================
# Variables
# ============================================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "sa-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
}

variable "db_endpoint" {
  description = "RDS PostgreSQL endpoint"
  type        = string
}

variable "db_password_secret_arn" {
  description = "ARN of Secrets Manager secret containing DB password"
  type        = string
}

# ============================================================================
# ECR Repositories
# ============================================================================
# Using existing ECR repositories created in terraform/shared

data "aws_ecr_repository" "cliente_core" {
  name = "cliente-core"
}

data "aws_ecr_repository" "vendas_core" {
  name = "vendas-core"
}

# Lifecycle policy to keep only last 10 images (only if not already managed)
resource "aws_ecr_lifecycle_policy" "cliente_core" {
  repository = data.aws_ecr_repository.cliente_core.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ============================================================================
# Security Groups
# ============================================================================

resource "aws_security_group" "alb" {
  name        = "vanessa-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vanessa-alb-sg"
  }
}

resource "aws_security_group" "ecs_tasks" {
  name        = "vanessa-ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow traffic from ALB"
    from_port       = 8081
    to_port         = 8082
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vanessa-ecs-tasks-sg"
  }
}

# ============================================================================
# Application Load Balancer
# ============================================================================

resource "aws_lb" "main" {
  name               = "vanessa-mudanca-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection       = false
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "vanessa-mudanca-alb"
  }
}

# Target Group for cliente-core
resource "aws_lb_target_group" "cliente_core" {
  name        = "cliente-core-tg"
  port        = 8081
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/api/clientes/actuator/health"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name    = "cliente-core-tg"
    Service = "cliente-core"
  }
}

# Listener HTTP (redirect to HTTPS in production)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cliente_core.arn
  }
}

# ============================================================================
# CloudWatch Log Groups
# ============================================================================

resource "aws_cloudwatch_log_group" "cliente_core" {
  name              = "/ecs/cliente-core"
  retention_in_days = 30

  tags = {
    Name    = "cliente-core-logs"
    Service = "cliente-core"
  }
}

resource "aws_cloudwatch_log_group" "vendas_core" {
  name              = "/ecs/vendas-core"
  retention_in_days = 30

  tags = {
    Name    = "vendas-core-logs"
    Service = "vendas-core"
  }
}

# ============================================================================
# IAM Roles
# ============================================================================

# ECS Task Execution Role (for pulling images and sending logs)
# Using existing role created in terraform/shared
data "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecutionRole"
}

# Additional permissions for Secrets Manager
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name = "ecs-task-execution-secrets-policy"
  role = data.aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          var.db_password_secret_arn
        ]
      }
    ]
  })
}

# ECS Task Role (for application to access AWS services)
resource "aws_iam_role" "cliente_core_task" {
  name = "clienteCoreTaskRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = "cliente-core-task-role"
    Service = "cliente-core"
  }
}

# Policy for application to access S3, Secrets Manager, etc.
resource "aws_iam_role_policy" "cliente_core_task" {
  name = "cliente-core-task-policy"
  role = aws_iam_role.cliente_core_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::vanessa-mudanca-documents/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:*:secret:vanessa/*"
        ]
      }
    ]
  })
}

# ============================================================================
# ECS Cluster
# ============================================================================

resource "aws_ecs_cluster" "main" {
  name = "vanessa-mudanca-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "vanessa-mudanca-cluster"
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  # Use 100% Fargate Spot for 70% cost savings
  # Spot instances can be interrupted with 2-minute warning (acceptable for stateless tasks)
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    base              = 0
    weight            = 100 # 100% Spot for maximum savings
  }

  # Fallback to on-demand Fargate only if Spot capacity unavailable
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 0 # 0% on-demand (only used as fallback)
  }
}

# ============================================================================
# ECS Task Definition - cliente-core
# ============================================================================

resource "aws_ecs_task_definition" "cliente_core" {
  family                   = "cliente-core"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = data.aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.cliente_core_task.arn

  container_definitions = jsonencode([
    {
      name      = "cliente-core"
      image     = "${data.aws_ecr_repository.cliente_core.repository_url}:latest"
      cpu       = 512
      memory    = 1024
      essential = true

      portMappings = [
        {
          containerPort = 8081
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = var.environment
        },
        {
          name  = "SPRING_DATASOURCE_URL"
          value = "jdbc:postgresql://${var.db_endpoint}/clientes"
        },
        {
          name  = "SPRING_DATASOURCE_USERNAME"
          value = "postgres"
        }
      ]

      secrets = [
        {
          name      = "SPRING_DATASOURCE_PASSWORD"
          valueFrom = var.db_password_secret_arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.cliente_core.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:8081/api/clientes/actuator/health || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name    = "cliente-core-task-definition"
    Service = "cliente-core"
  }
}

# ============================================================================
# ECS Service - cliente-core
# ============================================================================

resource "aws_ecs_service" "cliente_core" {
  name             = "cliente-core-service"
  cluster          = aws_ecs_cluster.main.id
  task_definition  = aws_ecs_task_definition.cliente_core.arn
  desired_count    = 2
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.cliente_core.arn
    container_name   = "cliente-core"
    container_port   = 8081
  }

  health_check_grace_period_seconds = 60

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  depends_on = [aws_lb_listener.http]

  tags = {
    Name    = "cliente-core-service"
    Service = "cliente-core"
  }
}

# ============================================================================
# Auto Scaling
# ============================================================================

resource "aws_appautoscaling_target" "cliente_core" {
  max_capacity       = 3 # Reduced from 10 to 3 for MVP cost control
  min_capacity       = 0 # Enables scale-to-zero during off-hours (50% savings)
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.cliente_core.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Scale based on CPU utilization
resource "aws_appautoscaling_policy" "cliente_core_cpu" {
  name               = "cliente-core-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.cliente_core.resource_id
  scalable_dimension = aws_appautoscaling_target.cliente_core.scalable_dimension
  service_namespace  = aws_appautoscaling_target.cliente_core.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# Scale based on Memory utilization
resource "aws_appautoscaling_policy" "cliente_core_memory" {
  name               = "cliente-core-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.cliente_core.resource_id
  scalable_dimension = aws_appautoscaling_target.cliente_core.scalable_dimension
  service_namespace  = aws_appautoscaling_target.cliente_core.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 80.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}

# ============================================================================
# Scheduled Scaling - Scale to Zero for Cost Optimization
# ============================================================================
# Scale UP: Weekday mornings (Monday-Friday 6:00 AM BRT / 9:00 AM UTC)
resource "aws_appautoscaling_scheduled_action" "cliente_core_scale_up_weekday_morning" {
  name               = "cliente-core-scale-up-weekday-morning"
  service_namespace  = aws_appautoscaling_target.cliente_core.service_namespace
  resource_id        = aws_appautoscaling_target.cliente_core.resource_id
  scalable_dimension = aws_appautoscaling_target.cliente_core.scalable_dimension

  schedule = "cron(0 9 ? * MON-FRI *)" # 6:00 AM BRT = 9:00 AM UTC
  timezone = "America/Sao_Paulo"

  scalable_target_action {
    min_capacity = 1 # Start with 1 task
    max_capacity = 3 # Allow auto-scaling up to 3
  }
}

# Scale DOWN to ZERO: Weekday nights (Monday-Friday 10:00 PM BRT / 1:00 AM UTC next day)
resource "aws_appautoscaling_scheduled_action" "cliente_core_scale_down_weekday_night" {
  name               = "cliente-core-scale-down-weekday-night"
  service_namespace  = aws_appautoscaling_target.cliente_core.service_namespace
  resource_id        = aws_appautoscaling_target.cliente_core.resource_id
  scalable_dimension = aws_appautoscaling_target.cliente_core.scalable_dimension

  schedule = "cron(0 1 ? * TUE-SAT *)" # 10:00 PM BRT = 1:00 AM UTC next day
  timezone = "America/Sao_Paulo"

  scalable_target_action {
    min_capacity = 0 # Scale to zero (50% cost savings)
    max_capacity = 0 # Force zero tasks
  }
}

# Scale DOWN to ZERO: Weekend all day (Saturday-Sunday)
resource "aws_appautoscaling_scheduled_action" "cliente_core_scale_down_weekend" {
  name               = "cliente-core-scale-down-weekend"
  service_namespace  = aws_appautoscaling_target.cliente_core.service_namespace
  resource_id        = aws_appautoscaling_target.cliente_core.resource_id
  scalable_dimension = aws_appautoscaling_target.cliente_core.scalable_dimension

  schedule = "cron(0 1 ? * SAT *)" # Saturday 1:00 AM UTC (Friday 10:00 PM BRT)
  timezone = "America/Sao_Paulo"

  scalable_target_action {
    min_capacity = 0 # Scale to zero for weekend
    max_capacity = 0
  }
}

# Scale UP: Monday morning (restart after weekend)
# Already covered by cliente_core_scale_up_weekday_morning which runs MON-FRI

# ============================================================================
# Outputs
# ============================================================================

output "ecr_repository_url_cliente_core" {
  description = "ECR repository URL for cliente-core"
  value       = data.aws_ecr_repository.cliente_core.repository_url
}

output "ecr_repository_url_vendas_core" {
  description = "ECR repository URL for vendas-core"
  value       = data.aws_ecr_repository.vendas_core.repository_url
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "cliente_core_service_name" {
  description = "Name of the cliente-core ECS service"
  value       = aws_ecs_service.cliente_core.name
}

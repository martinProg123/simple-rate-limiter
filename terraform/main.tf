terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_iam_policy_document" "ecs_task_execution_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "rate-limiter-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "rate_limiter" {
  name              = "/ecs/rate-limiter"
  retention_in_days = 1
}

resource "aws_security_group" "alb" {
  name        = "rate-limiter-alb-sg"
  description = "Security group for ALB"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_tasks" {
  name        = "rate-limiter-ecs-tasks-sg"
  description = "Security group for ECS tasks"

  ingress {
    from_port       = 3051
    to_port         = 3051
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "rate_limiter" {
  name               = "rate-limiter-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.public.ids
}

resource "aws_lb_target_group" "rate_limiter" {
  name        = "rate-limiter-tg"
  port        = 3051
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-499"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 5
    interval            = 30
  }
}

resource "aws_lb_listener" "rate_limiter" {
  load_balancer_arn = aws_lb.rate_limiter.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.rate_limiter.arn
  }
}

resource "aws_ecs_cluster" "rate_limiter" {
  name = "rate-limiter-cluster"
}

resource "aws_ecs_task_definition" "rate_limiter" {
  family                   = "rate-limiter"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "redis"
      image     = "redis:7-alpine"
      essential = true
      healthCheck = {
        command     = ["CMD-SHELL", "redis-cli ping"]
        interval    = 5
        timeout     = 3
        retries     = 3
        startPeriod = 10
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.rate_limiter.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "redis"
        }
      }
    },
    {
      name      = "node-backend"
      image     = "${var.docker_user}/node-backend:latest"
      essential = true
      environment = [
        { name = "PORT", value = tostring(var.node_port) }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.rate_limiter.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "node-backend"
        }
      }
    },
    {
      name      = "rate-limiter"
      image     = "${var.docker_user}/rate-limiter:latest"
      essential = true
      portMappings = [
        {
          protocol      = "tcp"
          containerPort = var.spring_port
          hostPort      = var.spring_port
        }
      ]
      environment = [
        { name = "SERVER_PORT",              value = tostring(var.spring_port) },
        { name = "REDIS_HOST",               value = "localhost" },
        { name = "REDIS_PORT",               value = "6379" },
        { name = "BACKEND_URL",              value = "http://localhost:${var.node_port}" },
        { name = "RATE_LIMITER_MAX_TOKENS",  value = tostring(var.rate_limiter_max_tokens) },
        { name = "RATE_LIMITER_REFILL_RATE", value = tostring(var.rate_limiter_refill_rate) },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.rate_limiter.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "rate-limiter"
        }
      }
    },
  ])
}

resource "aws_ecs_service" "rate_limiter" {
  name            = "rate-limiter"
  cluster         = aws_ecs_cluster.rate_limiter.id
  task_definition = aws_ecs_task_definition.rate_limiter.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = data.aws_subnets.public.ids
    security_groups = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.rate_limiter.arn
    container_name   = "rate-limiter"
    container_port   = var.spring_port
  }

  depends_on = [aws_lb_listener.rate_limiter]
}

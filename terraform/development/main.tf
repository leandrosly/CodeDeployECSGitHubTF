# AWS Provider
provider "aws" {
  version = "~> 2.59"
  region  = "ap-northeast-2"
}

# VPC
resource "aws_vpc" "vpc-dev" {
  cidr_block = "172.22.0.0/16"
  instance_tenancy = "default"
  enable_dns_support = true
  enable_dns_hostnames = true
  assign_generated_ipv6_cidr_block = false

  tags = {
    Name = "ecs-deploy-dev"
  }
}

# AZs
data "aws_availability_zones" "available" {}

# Subnets
resource "aws_subnet" "subnet" {
  vpc_id                   = aws_vpc.vpc-dev.id
  count                    = length(data.aws_availability_zones.available.names)
  cidr_block               = cidrsubnet(aws_vpc.vpc-dev.cidr_block, 8, (count.index + 1))
  availability_zone        = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch  = true

  tags = {
    Name        = "ecs-deploy-dev-${element(data.aws_availability_zones.available.names, count.index)}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc-dev.id

  tags = {
    Name = "ecs-deploy-dev"
  }
}

# Default Security Group
resource "aws_default_security_group" "def_sg" {
  vpc_id = aws_vpc.vpc-dev.id

  ingress {
    protocol  = -1
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Default Route Table
resource "aws_default_route_table" "def_rt" {
  default_route_table_id = aws_vpc.vpc-dev.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "ecs-deploy-dev-default-route-table"
  }
}

# Cluster
resource "aws_ecs_cluster" "cluster" {
  name = "ecs-deploy-dev"
}

# ALB
resource "aws_lb" "alb" {
  name               = "ecs-deploy-dev"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.subnet.*.id

  enable_deletion_protection = false

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "ecs-deploy-dev"
  }
}

# Target Group
resource "aws_lb_target_group" "alb_tg1" {
  name        = "ecs-deploy-dev-1"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.vpc-dev.id
}

# Target Group 2
resource "aws_lb_target_group" "alb_tg2" {
  name        = "ecs-deploy-dev-2"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.vpc-dev.id
}

# Listener
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port = "80"
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.alb_tg1.arn
  }
}

# Task Definition
resource "aws_ecs_task_definition" "task_def" {
  family = "ecs-deploy-dev"
  network_mode = "awsvpc"
  container_definitions = file("task-definitions/service.json")
  requires_compatibilities = ["FARGATE"]
  cpu = "256"
  memory = "512"
}

# Service
resource "aws_ecs_service" "service" {
  name            = "ecs-deploy-dev"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task_def.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  scheduling_strategy = "REPLICA"
  platform_version = "LATEST"

  lifecycle {
    ignore_changes = [
      platform_version
    ]
  }

  deployment_controller {
      type = "CODE_DEPLOY"
  }

  depends_on = [aws_lb_listener.alb_listener,aws_lb_target_group.alb_tg1,aws_lb.alb]

  network_configuration {
    assign_public_ip = true
    subnets = aws_subnet.subnet.*.id
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.alb_tg1.arn
    container_name   = "ecs-deploy-dev-sample-app"
    container_port   = 80
  }

}

# CodeDeploy App
resource "aws_codedeploy_app" "cd_app" {
  compute_platform = "ECS"
  name             = "ecs-deploy-dev"
}

# CodeDeploy Deployment Group
resource "aws_codedeploy_deployment_group" "cd_dg" {
  app_name               = aws_codedeploy_app.cd_app.name
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  deployment_group_name  = "ecs-deploy-dev"
  service_role_arn       = "arn:aws:iam::688980480079:role/CodeDeployServiceRole"

  depends_on = [aws_codedeploy_app.cd_app]

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
      wait_time_in_minutes = 0
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.cluster.name
    service_name = aws_ecs_service.service.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.alb_listener.arn]
      }

      target_group {
        name = aws_lb_target_group.alb_tg1.name
      }

      target_group {
        name = aws_lb_target_group.alb_tg2.name
      }
    }
  }
}

# Bucket
resource "aws_s3_bucket" "bucket" {
  bucket = "ecs-deploy-dev"
  acl    = "private"
}

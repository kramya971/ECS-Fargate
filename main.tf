# Provider block to specify AWS as the provider
terraform {
  required_providers {
     aws = {
       source  = "hashicorp/aws"
       version = "~> 4.60.0"
     }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-west-2"
}

# Create a VPC for the ECS cluster
resource "aws_vpc" "ecs_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create subnets for the ECS cluster
resource "aws_subnet" "ecs_subnet_1" {
  vpc_id = aws_vpc.ecs_vpc.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_subnet" "ecs_subnet_2" {
  vpc_id = aws_vpc.ecs_vpc.id
  cidr_block = "10.0.2.0/24"
}

# Create an internet gateway for the ECS cluster
resource "aws_internet_gateway" "ecs_igw" {
  vpc_id = aws_vpc.ecs_vpc.id
}

# Attach the internet gateway to the VPC
#resource "aws_vpc_attachment" "ecs_igw_attachment" {
#  vpc_id = aws_vpc.ecs_vpc.id
#  internet_gateway_id = aws_internet_gateway.ecs_igw.id
#}

# Attach the internet gateway to the VPC
resource "aws_internet_gateway_attachment" "ecs" {
  internet_gateway_id = aws_internet_gateway.ecs_igw.id
  vpc_id              = aws_vpc.ecs_vpc.id
}

# Create a security group for the ALB
resource "aws_security_group" "alb_sg" {
  name_prefix = "alb_sg"
  vpc_id = aws_vpc.ecs_vpc.id

  ingress {
    from_port = 3000
    to_port = 3000
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an ALB and a listener
resource "aws_lb" "ecs_alb" {
  name = "ecs-alb"
  load_balancer_type = "application"
  subnets = [aws_subnet.ecs_subnet_1.id, aws_subnet.ecs_subnet_2.id]
  security_groups = [aws_security_group.alb_sg.id]
}

resource "aws_lb_listener" "ecs_listener" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port = 3000
  protocol = "tcp"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.ecs_target_group.arn
  }
}

# Create a target group for the ECS service
resource "aws_lb_target_group" "ecs_target_group" {
  name = "ecs-target-group"
  port = 3000
  protocol = "tcp"
  vpc_id = aws_vpc.ecs_vpc.id
  health_check {
    path = "/"
    interval = 30
    timeout = 10
    healthy_threshold = 3
    unhealthy_threshold = 3
    matcher = "200-299"
  }
}

# Create the ECS cluster and Fargate task definition
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "my-ecs-cluster"
}

resource "aws_ecs_task_definition" "my_task_definition" {
  family = "my-task-definition"
  network_mode = "awsvpc"

  container_definitions = jsonencode([
    {
      name = "my-container"
      image = "my-image"
      portMappings = [
        {
          containerPort = 3000
          protocol = "tcp"
        }
      ]
    }
  ])
}

# Create an ECS service
resource "aws_ecs_service" "my_service" {
  name            = "my-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.my_task_definition.arn
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = true
    subnets          = ["aws_subnet.ecs_subnet_1.id", "aws_subnet.ecs_subnet_2.id"]
    security_groups  = [aws_security_group.alb_sg.id]
  }
}

# Create an IAM role for ECS task execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

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
}

# Attach policies to the ECS task execution role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_task_execution_role.name
}

#variables
variable "image_tag" {
  type = string
}

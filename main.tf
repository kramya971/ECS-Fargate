# Provider block to specify AWS as the provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-west-2"
}

# Create VPC and subnet
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "my_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
}

# Create EC2 instance
resource "aws_instance" "my_instance" {
  ami           = var.ami
  instance_type = var.instance_type
  vpc_security_group_ids = [aws_security_group.my_sg.id]
  subnet_id     = aws_subnet.my_subnet.id
  availability_zone = "us-west-2a"

  tags = {
    Name = "My EC2 Instance"
  }
}

# Create Security Group for EC2 instance
resource "aws_security_group" "my_sg" {
  name_prefix = "my_sg_"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "My Security Group"
  }
}

terraform {
  backend "s3" {
    bucket = "ram-tes"
    #key    = "path/key"
    region = "us-west-2a"
  }
}


variable "instance_type" {
  type = string
}


variable "ami" {
  type = string
}

##########################################
# Networking
##########################################

resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "devops-project-vpc"
  }
}

resource "aws_internet_gateway" "main-igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "devops-api-igw"
  }
}

# Public Subnet 1 (Availability Zone A)
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-southeast-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "devops-public-subnet-1"
  }
}

# Public Subnet 2 (Availability Zone B — High Availability)
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-southeast-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "devops-public-subnet-2"
  }
}

# Private Subnet (used by ASG / ECS EC2 launch type)
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-southeast-2a"

  tags = {
    Name = "devops-private-subnet-1"
  }
}

resource "aws_eip" "nat-eip" {
  domain = "vpc"

  tags = {
    Name = "devops-api-nat-eip"
  }
}

resource "aws_nat_gateway" "main-nat-gw" {
  allocation_id = aws_eip.nat-eip.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "devops-api-nat-gw"
  }

  depends_on = [aws_internet_gateway.main-igw]
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main-igw.id
  }

  tags = {
    Name = "devops-public-route-table"
  }
}

resource "aws_route_table_association" "public_1_assoc" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2_assoc" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main-nat-gw.id
  }

  tags = {
    Name = "devops-private-route-table"
  }
}

resource "aws_route_table_association" "private_1_assoc" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_rt.id
}

######################################
# ECR
######################################

resource "aws_ecr_repository" "main" {
  name                 = "devops-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "devops-api-ecr"
  }
}

######################################
# ECS
######################################

resource "aws_ecs_cluster" "main" {
  name = "devops-api"
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/devops-api"
  retention_in_days = 7
}

# Launch template required by the ASG (used for EC2-backed ECS capacity if needed).
# For pure Fargate workloads you can remove the ASG and launch template entirely.
data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

resource "aws_launch_template" "ecs_lt" {
  name_prefix   = "devops-api-lt-"
  image_id      = data.aws_ami.ecs_optimized.id
  instance_type = "t3.micro"

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "devops-api-ecs-instance"
    }
  }
}

resource "aws_autoscaling_group" "main" {
  name                = "devops-api-asg"
  vpc_zone_identifier = [aws_subnet.private_1.id]
  desired_capacity    = 1
  max_size            = 3
  min_size            = 1

  launch_template {
    id      = aws_launch_template.ecs_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "devops-api-asg"
    propagate_at_launch = true
  }
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "devops-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_attach" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "api_task" {
  family                   = "devops-api-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "devops-api-container"
      image     = "${aws_ecr_repository.main.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = "ap-southeast-2"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_security_group" "ecs_sg" {
  name        = "devops-api-sg"
  description = "Security group for ECS cluster"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
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

resource "aws_ecs_service" "main" {
  name            = "devops-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
}

#########################
# Outputs
#########################
output "ecr_repository_url" {
  value       = aws_ecr_repository.main.repository_url
  description = "The URL of the ECR repository"
}

output "ecr_repository_arn" {
  value       = aws_ecr_repository.main.arn
  description = "The ARN of the ECR repository"
}
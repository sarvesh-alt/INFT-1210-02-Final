###############################################################################
# Section 1: Provider
###############################################################################
provider "aws" {
  region = var.region
}

###############################################################################
# Section 2: Networking (VPC, Subnets, IGW, Route Tables)
###############################################################################
resource "aws_vpc" "final_more_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "final-more-vpc"
  }
}

# Primary public subnet for ALB (Availability Zone A)
resource "aws_subnet" "final_more_pub_subnet_a" {
  vpc_id                  = aws_vpc.final_more_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "final-more-pub-subnet-a"
  }
}

# Second public subnet for ALB (Availability Zone B)
resource "aws_subnet" "final_more_pub_subnet_b" {
  vpc_id                  = aws_vpc.final_more_vpc.id
  cidr_block              = "10.0.3.0/24"  # Ensure this CIDR block does not overlap with others
  availability_zone       = var.availability_zone_b
  map_public_ip_on_launch = true

  tags = {
    Name = "final-more-pub-subnet-b"
  }
}

# Private subnet for ECS tasks
resource "aws_subnet" "final_more_priv_subnet" {
  vpc_id            = aws_vpc.final_more_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = var.availability_zone

  tags = {
    Name = "final-more-priv-subnet"
  }
}

# Internet Gateway for public subnets
resource "aws_internet_gateway" "final_more_igw" {
  vpc_id = aws_vpc.final_more_vpc.id

  tags = {
    Name = "final-more-igw"
  }
}

# Route Table for public subnets
resource "aws_route_table" "final_more_pub_rt" {
  vpc_id = aws_vpc.final_more_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.final_more_igw.id
  }

  tags = {
    Name = "final-more-pub-rt"
  }
}

resource "aws_route_table_association" "final_more_pub_assoc_a" {
  subnet_id      = aws_subnet.final_more_pub_subnet_a.id
  route_table_id = aws_route_table.final_more_pub_rt.id
}

resource "aws_route_table_association" "final_more_pub_assoc_b" {
  subnet_id      = aws_subnet.final_more_pub_subnet_b.id
  route_table_id = aws_route_table.final_more_pub_rt.id
}

###############################################################################
# Section 3: Security Groups
###############################################################################
# Security Group for ALB – allows HTTP inbound
resource "aws_security_group" "final_more_alb_sg" {
  name        = "final-more-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.final_more_vpc.id

  ingress {
    description = "Allow HTTP inbound"
    from_port   = 80
    to_port     = 80
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
    Name = "final-more-alb-sg"
  }
}

# Security Group for ECS tasks – restrict inbound to only traffic from ALB on port 5000
resource "aws_security_group" "final_more_ecs_sg" {
  name        = "final-more-ecs-sg"
  description = "Security group for ECS tasks (Fargate)"
  vpc_id      = aws_vpc.final_more_vpc.id

  ingress {
    description     = "Allow inbound from ALB on port 5000"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.final_more_alb_sg.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "final-more-ecs-sg"
  }
}

###############################################################################
# Section 4: Application Load Balancer & Target Group
###############################################################################
resource "aws_lb" "final_more_alb" {
  name               = "final-more-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.final_more_alb_sg.id]
  subnets            = [aws_subnet.final_more_pub_subnet_a.id, aws_subnet.final_more_pub_subnet_b.id]

  tags = {
    Name = "final-more-alb"
  }
}

resource "aws_lb_target_group" "final_more_tg" {
  name        = "final-more-tg"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.final_more_vpc.id
  target_type = "ip"    # Required for awsvpc mode

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200-399"
  }

  tags = {
    Name = "final-more-tg"
  }
}

resource "aws_lb_listener" "final_more_listener" {
  load_balancer_arn = aws_lb.final_more_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.final_more_tg.arn
  }

  tags = {
    Name = "final-more-http-listener"
  }
}

###############################################################################
# Section 5: IAM Roles
###############################################################################
# Create ECS Task Role (import if it already exists)
resource "aws_iam_role" "final_more_ecs_task_role" {
  name = "final-more-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "ecs-tasks.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "final-more-ecs-task-role"
  }
}

###############################################################################
# Section 6: ECS Cluster, Task Definition, and Service (Fargate)
###############################################################################
resource "aws_ecs_cluster" "final_more_ecs_cluster" {
  name = "final-more-ecs-cluster"

  tags = {
    Name = "final-more-ecs-cluster"
  }
}

# Reference the externally created ECR repository using a variable for the image URI.
resource "aws_ecs_task_definition" "final_more_task_def" {
  family                   = "final-more-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"   # 0.25 vCPU
  memory                   = "512"   # 512 MB

  container_definitions = jsonencode([
    {
      name         = "final-api-container",
      image        = var.api_container_image,
      essential    = true,
      portMappings = [
        {
          containerPort = 5000,
          hostPort      = 5000
        }
      ],
      environment = [
        {
          name  = "WELCOME_MESSAGE",
          value = "Welcome to final More Final Test API Server"
          # Adjust the text as required. In this example, the welcome message uses "final More".
        }
      ]
    }
  ])

  execution_role_arn = var.ecs_execution_role_arn
  task_role_arn      = aws_iam_role.final_more_ecs_task_role.arn

  tags = {
    Name = "final-more-task-def"
  }
}

resource "aws_ecs_service" "final_more_ecs_service" {
  name            = "final-more-ecs-service"
  cluster         = aws_ecs_cluster.final_more_ecs_cluster.id
  task_definition = aws_ecs_task_definition.final_more_task_def.arn
  launch_type     = "FARGATE"
  desired_count   = 2

  network_configuration {
    subnets         = [aws_subnet.final_more_priv_subnet.id]
    security_groups = [aws_security_group.final_more_ecs_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.final_more_tg.arn
    container_name   = "final-api-container"
    container_port   = 5000
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  depends_on = [aws_lb_listener.final_more_listener]

  tags = {
    Name = "final-more-ecs-service"
  }
}

###############################################################################
# Section 7: Autoscaling for ECS Service
###############################################################################
resource "aws_appautoscaling_target" "final_more_ecs_asg_target" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.final_more_ecs_cluster.name}/${aws_ecs_service.final_more_ecs_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = 2
  max_capacity       = 5
}

resource "aws_appautoscaling_policy" "final_more_ecs_asg_scale_out" {
  name               = "final-more-ecs-scale-out"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.final_more_ecs_asg_target.resource_id
  scalable_dimension = aws_appautoscaling_target.final_more_ecs_asg_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.final_more_ecs_asg_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 90.0
    scale_out_cooldown = 120
    scale_in_cooldown  = 120
  }
}

resource "aws_appautoscaling_policy" "final_more_ecs_asg_scale_in" {
  name               = "final-more-ecs-scale-in"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.final_more_ecs_asg_target.resource_id
  scalable_dimension = aws_appautoscaling_target.final_more_ecs_asg_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.final_more_ecs_asg_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 50.0
    scale_out_cooldown = 120
    scale_in_cooldown  = 120
  }
}

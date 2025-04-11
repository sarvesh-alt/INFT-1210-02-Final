variable "region" {
  description = "AWS Region to deploy into"
  type        = string
  default     = "ca-central-1"
}

variable "availability_zone" {
  description = "Primary AWS Availability Zone"
  type        = string
  default     = "ca-central-1a"
}

variable "availability_zone_b" {
  description = "Second AWS Availability Zone"
  type        = string
  default     = "ca-central-1b"
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
  default     = "615299769322"
}

variable "api_container_image" {
  description = "Docker image URI in ECR for the final API"
  type        = string
  default     = ""  # Not required if using the ECR repository output
}

variable "ecs_execution_role_arn" {
  description = "IAM role ARN for ECS task execution"
  type        = string
  default     = "arn:aws:iam::615299769322:role/ecsTaskExecutionRole"
}

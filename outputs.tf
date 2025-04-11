output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.final_more_vpc.id
}

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.final_more_alb.dns_name
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.final_more_ecs_cluster.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.final_more_ecs_service.name
}

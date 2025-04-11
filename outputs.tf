output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.more_final_vpc.id
}

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.more_final_alb.dns_name
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.more_final_ecs_cluster.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.more_final_ecs_service.name
}

output "alb_dns_name" {
  description = "Public URL to hit your frontend"
  value       = "http://${aws_lb.frontend.dns_name}"
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "backend_service_discovery_dns" {
  description = "Internal DNS name the frontend uses to reach the backend"
  value       = "backend.${var.project_name}.internal"
}

output "ecr_backend_repository_url" {
  description = "Push the Flask image here -- build-and-push.sh reads this"
  value       = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_repository_url" {
  description = "Push the Express image here -- build-and-push.sh reads this"
  value       = aws_ecr_repository.frontend.repository_url
}

output "vpc_id" {
  value = aws_vpc.main.id
}

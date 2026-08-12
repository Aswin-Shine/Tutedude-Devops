output "backend_instance_id" {
  value = aws_instance.backend_server.id
}

output "backend_public_ip" {
  value = aws_instance.backend_server.public_ip
}

output "backend_private_ip" {
  description = "Used internally by the frontend instance to reach the API -- exposed here for debugging"
  value       = aws_instance.backend_server.private_ip
}

output "backend_url" {
  description = "Direct public access to the Flask API (spec requires it reachable from the internet on its own port)"
  value       = "http://${aws_instance.backend_server.public_ip}:${var.backend_port}/api/submit"
}

output "frontend_instance_id" {
  value = aws_instance.frontend_server.id
}

output "frontend_public_ip" {
  value = aws_instance.frontend_server.public_ip
}

output "frontend_url" {
  value = "http://${aws_instance.frontend_server.public_ip}:${var.frontend_port}"
}

output "backend_ssh_command" {
  value = "ssh -i <path-to-${var.key_name}.pem> ubuntu@${aws_instance.backend_server.public_ip}"
}

output "frontend_ssh_command" {
  value = "ssh -i <path-to-${var.key_name}.pem> ubuntu@${aws_instance.frontend_server.public_ip}"
}

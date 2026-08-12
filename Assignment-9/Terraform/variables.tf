variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Prefix for resource names"
  type        = string
  default     = "tutedude-cicd"
}

variable "instance_type" {
  description = "EC2 instance type. Jenkins + both apps on one box needs real RAM."
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Name of an EXISTING EC2 key pair in this region, used for SSH access"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH in. Set to your own IP/32, not 0.0.0.0/0."
  type        = string
}

variable "github_repo_url" {
  description = "HTTPS URL of the app repo (monorepo containing both backend/ and frontend/)"
  type        = string
  default     = "https://github.com/Aswin-Shine/tutedude-flask-app.git"
}

variable "backend_port" {
  description = "Port the Flask backend listens on"
  type        = number
  default     = 5000
}

variable "frontend_port" {
  description = "Port the Express frontend listens on"
  type        = number
  default     = 3000
}

variable "jenkins_port" {
  description = "Port the Jenkins web UI listens on"
  type        = number
  default     = 8080
}

variable "mongo_uri" {
  description = "MongoDB Atlas connection string for the Flask backend."
  type        = string
  sensitive   = true
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Prefix used for naming all resources"
  type        = string
  default     = "tutedude-assignment6"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC created for this part"
  type        = string
  default     = "10.1.0.0/16" # different range from Part 2's 10.0.0.0/16 -- these are separate VPCs, no risk of overlap mattering, but keeping them visually distinct avoids confusion when reading tfvars side by side
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets -- needs at least 2, in different AZs, for the ALB"
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "Provide at least 2 subnet CIDRs in different AZs for the ALB."
  }
}

variable "image_tag" {
  description = "Tag used for both ECR images. build-and-push.sh pushes this same tag."
  type        = string
  default     = "latest"
}

variable "backend_container_port" {
  description = "Port the Flask container listens on inside the container"
  type        = number
  default     = 5001
}

variable "frontend_container_port" {
  description = "Port the Express/Node container listens on inside the container"
  type        = number
  default     = 3000
}

variable "backend_env_vars" {
  description = "Non-secret extra environment variables for the backend container"
  type        = map(string)
  default     = {}
}

variable "mongo_uri" {
  description = "MongoDB Atlas connection string for the Flask backend. Plain env var, matching the Part 1/2 call to leave the cluster credential as-is since it's temporary."
  type        = string
  sensitive   = true
  default     = "mongodb+srv://ashwinsh91_db_user:NH56mlwbxJFyhORv@cluster0.9n2vi99.mongodb.net/tutedude?retryWrites=true&w=majority"
}

variable "frontend_env_vars" {
  description = "Extra environment variables for the frontend container. BACKEND_URL is added automatically."
  type        = map(string)
  default     = {}
}

variable "task_cpu" {
  description = "Fargate task CPU units (256 = .25 vCPU, cheapest valid Fargate value)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory in MB (must pair validly with task_cpu)"
  type        = number
  default     = 512
}

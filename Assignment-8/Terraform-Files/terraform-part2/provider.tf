provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "tutedude-devops-assignment"
      ManagedBy   = "terraform"
      Environment = var.environment
      Part        = "part2-two-instances"
    }
  }
}

terraform {
  backend "s3" {
    bucket         = "tutedude-tfstate-aswin-shine" # same bucket as Part 1/2 — update if you renamed it
    key            = "part3/ecs-fargate/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "tutedude-tfstate-lock"
    encrypt        = true
  }
}

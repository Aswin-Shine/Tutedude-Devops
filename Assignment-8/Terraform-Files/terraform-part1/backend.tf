# Backend values are hardcoded because Terraform does not allow variable
# interpolation in a backend block. These MUST match the bootstrap outputs.
# Run `terraform apply` in ../bootstrap first, then update these values.

terraform {
  backend "s3" {
    bucket         = "tutedude-tfstate-aswin-shine" # from bootstrap output: state_bucket_name
    key            = "part1/ec2-single-instance/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "tutedude-tfstate-lock" # from bootstrap output: lock_table_name
    encrypt        = true
  }
}

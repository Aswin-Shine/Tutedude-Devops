# Reuses the same state bucket + lock table created for Part 1.
# Only the key changes, so Part 1 and Part 2 state files don't collide.

terraform {
  backend "s3" {
    bucket         = "tutedude-tfstate-aswin-shine" # same bucket as Part 1 — update if you renamed it
    key            = "part2/two-instances/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "tutedude-tfstate-lock"
    encrypt        = true
  }
}

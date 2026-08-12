# Part 3 — Flask + Express on ECS Fargate via ECR + ALB (Terraform)

Own VPC (2 public subnets, 2 AZs — ALB's hard minimum), own ECR repos,
ECS cluster with two Fargate services. Frontend sits behind the ALB;
backend is internal-only, reached via Cloud Map DNS (`backend.<project>.internal`)
-- kept that way on purpose, not routed through the ALB.

## Run order (this one has a real chicken-and-egg step)

1. **State backend** — same S3 bucket + DynamoDB table as Part 1/2, different
   `key`. Create it first if you haven't.

2. **First apply — infra only, expect failing tasks:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```
   The ECR repos are empty at this point. ECS will try to start tasks
   immediately and fail with `CannotPullContainerError` — expected, not a
   bug. The repos, cluster, ALB, and networking all still get created
   correctly.

3. **Build and push the images:**
   ```bash
   ./build-and-push.sh
   ```
   Clones the app repo fresh into a temp dir, builds both images, pushes
   `:latest` to the two ECR repos `terraform apply` just created.

4. **Force the services to actually pull the new images** — ECS does not
   watch `:latest` for changes on its own, a tag push alone doesn't
   restart anything:
   ```bash
   aws ecs update-service --cluster tutedude-assignment6-cluster \
     --service tutedude-assignment6-backend-svc --force-new-deployment --region eu-north-1

   aws ecs update-service --cluster tutedude-assignment6-cluster \
     --service tutedude-assignment6-frontend-svc --force-new-deployment --region eu-north-1
   ```
   (`build-and-push.sh` prints these commands at the end so you don't have
   to remember cluster/service names.)

5. **Verify:**
   ```bash
   terraform output alb_dns_name
   ```
   Give it a minute or two after the forced deployment for tasks to go
   `RUNNING` and the target group to report `healthy`.

## What changed from the files you already had

- Added `provider.tf` — `var.aws_region` existed but nothing set it, so it
  was doing nothing. Real bug, not a style fix.
- Added `network.tf` — VPC/subnets were previously an input (`var.vpc_id`,
  `var.public_subnet_ids`), assumed to already exist. Spec requires
  Terraform to create them, so now it does.
- Added `ecr.tf` — same story, spec requires Terraform to create the two
  repos; previously `backend_image_url`/`frontend_image_url` assumed
  images already existed somewhere.
- Removed the Secrets Manager IAM policy and `mongo_secret_arn` — Mongo
  URI is now a plain `MONGO_URI` environment variable in the task
  definition, matching the Part 1/2 decision to leave that credential as
  plaintext since the cluster's temporary. `console-steps.md` still
  describes the Secrets Manager version; noted as stale at the top of
  that file rather than deleted, since the steps are still correct if you
  ever do want that path.
- ALB still fronts only the frontend service — backend stays reachable
  only via Cloud Map DNS from inside the VPC, no path-based ALB rule
  added for it. Your call, kept as-is.

## Known gaps

- `build-and-push.sh` isn't run automatically by Terraform (no
  `local-exec`) — building Docker images inside a Terraform run is fragile
  and hard to debug when it fails. A separate script you run explicitly is
  more predictable, at the cost of the manual step 3/4 above.
- Both ECS services rebuild nothing on `terraform apply` alone — if you
  change app code, you re-run `build-and-push.sh` and force a new
  deployment, `apply` by itself won't pick it up since the task definition
  still says `:latest` either way.
- `image_tag_mutability = "MUTABLE"` on both ECR repos, needed because
  everything pushes to the same `:latest` tag. Fine for an assignment;
  in a real pipeline you'd tag by commit SHA and make repos immutable so a
  bad push can't silently overwrite a known-good image.
- `force_delete = true` on both ECR repos means `terraform destroy` will
  happily delete them along with whatever images are still in them —
  intentional for easy teardown here, would not want this on anything
  you're trying to protect.

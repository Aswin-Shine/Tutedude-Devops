# Part 2 — Flask + Express on Separate EC2 Instances (Terraform)

Owned VPC this time (spec explicitly asks for VPC/subnet resources), not
the default VPC used in Part 1. One public subnet, both instances in it --
security groups do the actual access control, not subnet placement.

## Run order

State backend is shared with Part 1 (same S3 bucket + DynamoDB table,
different state `key`). If you haven't created that bucket/table yet, do
that first -- not repeated here.

```bash
cp terraform.tfvars.example terraform.tfvars
# edit: key_name, allowed_ssh_cidr at minimum
terraform init
terraform plan
terraform apply
```

```bash
terraform output frontend_url
terraform output backend_url
```

## What's actually going on

- Backend instance: clones the repo, runs `docker compose up -d --build
  backend` only. Stays on port 5001 -- Part 2 spec explicitly said not to
  change it, unlike Part 1.
- Frontend instance: clones the repo, but the repo's compose file points
  `BACKEND_URL` at the Docker-internal hostname `backend`, which doesn't
  exist once the two services aren't in the same Compose network anymore.
  `user_data` writes a `docker-compose.override.yml` that overrides just
  that one env var to the backend instance's **private IP** before
  running `docker compose up -d --build frontend`.
- Backend SG allows port 5001 from two sources: the frontend SG
  specifically (for the private-IP path above) and `0.0.0.0/0` (spec
  requires the backend also reachable directly from the internet, not
  just from the frontend).

## Known gaps

- **Ordering race.** `depends_on` + the `private_ip` reference guarantee
  the backend EC2 *instance* exists before the frontend one is created --
  they do NOT guarantee the backend's Docker container has finished
  building and starting. If you hit the frontend URL within the first
  ~30-60s and immediately submit the form, the API call might fail with a
  connection error. Wait for both `user-data.log` files to show
  `docker compose up` completing, or just give it 2 min after `apply`.
- Both instances rebuild the full app image from source on every boot
  (`--build`, no registry, no cache). Same tradeoff as Part 1 -- fine for
  a graded demo, not how you'd run this for real.
- Backend is now reachable on 5001 from the entire internet, not just the
  frontend. Spec required this, but it's a wider blast radius than
  Part 1's single-instance version where the backend was only reachable
  via `localhost`.
- Same MongoDB Atlas credentials hardcoded in the repo as before --
  unchanged, per your earlier call.
- No `restart:` policy in the repo's `docker-compose.yml` per service --
  a crashed container on either instance stays down until someone
  manually re-runs `docker compose up -d`.

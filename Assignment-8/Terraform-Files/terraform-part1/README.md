# Part 1 — Flask + Express on Single EC2 (Terraform, Docker Compose)

## Run order

**1. Create the state backend (once):** see bucket/table creation commands
you already have — not duplicated here to avoid a second source of truth.

**2. Deploy the instance:**
```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: set key_name and allowed_ssh_cidr at minimum
terraform init
terraform plan
terraform apply
```

**3. Verify:**
```bash
terraform output frontend_url
# open that URL
```
`user_data` installs Docker, clones the repo, patches the backend's host
port mapping to 5000, and runs `docker compose up -d --build`. Takes
longer than the systemd version to come up — Docker install + image
builds, not just pip/npm install. Give it 2-3 min, not 1.

## Known gaps

- **Deviates from literal assignment wording.** Spec says install
  Python/Node.js and run the apps directly; this runs them in Docker
  instead. Functionally identical from the browser, but if grading checks
  for direct host installs specifically, this doesn't match. You made this
  call knowingly — flagging again so it's not a surprise later.
- `key_name` must already exist in `eu-north-1`. Terraform doesn't create it.
- `allowed_ssh_cidr` has no default — set your own IP, don't leave it open.
- Backend/frontend ports open to `0.0.0.0/0` for grading convenience.
- `docker compose up -d --build` builds images fresh on every instance
  boot from source — no image registry, no caching. Fine for a one-shot
  assignment demo, wasteful/slow if you rebuild instances often.
- No healthcheck / restart policy defined in the repo's `docker-compose.yml`
  itself, so if a container crashes post-boot it won't come back unless
  Docker's own default restart behavior kicks in (it currently has none
  set — check `restart:` isn't defined per service, meaning a crash stays
  crashed until someone re-runs `docker compose up -d`).
- MongoDB Atlas credentials still hardcoded in the repo — you already
  said that's fine since the cluster is temporary, just repeating the
  connection point since Terraform doesn't manage or rotate it either way.

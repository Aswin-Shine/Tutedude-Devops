> **Note:** written when this was going to be a manual-console build. The
> Terraform config in this folder now does all of this automatically
> (VPC, ECR, ECS, ALB, Cloud Map). Kept for reference / understanding what
> each resource is actually for, not as steps to follow anymore. Two
> things below are now stale: Secrets Manager (this version uses a plain
> `MONGO_URI` env var, matching the Part 1/2 call), and the VPC/subnets
> being pre-existing (Terraform creates its own VPC now).

# ECS Console Steps — Flask backend + Express frontend on Fargate

Architecture: ALB → frontend service (public) → backend service, reached via
Cloud Map internal DNS, not the ALB. Both services need public IPs since
you have no NAT gateway.

---

## 1. IAM execution role

ECS needs this to pull from your private ECR repos and write logs.

1. IAM → Roles → **Create role**
2. Trusted entity: **AWS service** → Use case: **Elastic Container Service** → **Elastic Container Service Task**
3. Attach policy: `AmazonECSTaskExecutionRolePolicy`
4. Name it `tutedude-assignment6-ecs-execution-role` → Create role

If you skip this, task creation won't fail — it'll fail later at runtime with `CannotPullContainerError`, which is a confusing place to debug it. [Certain]

---

## 2. Security groups

VPC → Security Groups → **Create security group**, three times.

**`alb-sg`**
- Inbound: HTTP (80), source `0.0.0.0/0`
- Outbound: leave default (all traffic)

**`frontend-sg`**
- Inbound: Custom TCP, port **3000**, source = **`alb-sg`** (select the security group, not a CIDR)
- Outbound: default

**`backend-sg`**
- Inbound: Custom TCP, port **5001**, source = **`frontend-sg`**
- Outbound: default

The source-as-security-group step is where people default back to `0.0.0.0/0` because it's the familiar option — don't. That's the only thing actually preventing the backend from being open to the internet, since there's no private subnet doing that job here. [Certain]

---

## 3. CloudWatch log groups

Skip manual creation — when you build the task definition in step 5, tick "Use log collection" and the console creates the log group for you (`/ecs/<task-family-name>`).

---

## 4. ECS Cluster

ECS → Clusters → **Create cluster**

- Cluster name: `tutedude-assignment6-cluster`
- Infrastructure: **AWS Fargate (serverless)**
- Leave Cloud Map/namespace settings alone here — do it separately in step 5a, the wizard version is less flexible about service names.
- Create

---

## 5a. Cloud Map namespace (for backend service discovery)

Separate service: search **Cloud Map** in console.

1. **Create namespace**
2. Type: **API calls and DNS queries in VPC** (private DNS)
3. Name: `tutedude-assignment6.internal`
4. VPC: your VPC
5. Create

This gives you a namespace. The actual service record inside it gets created automatically when you attach service discovery to the ECS service in step 7 — don't try to pre-create the service record here, ECS wants to own that.

---

## 5a-2. Secrets Manager — do this before task definitions

Your compose file has `MONGO_URI` with a live username/password in plaintext.
That credential is now exposed (you pasted it into this chat) — **rotate it
in Atlas first** (Database Access → edit user → new password), then:

1. Secrets Manager → **Store a new secret**
2. Secret type: **Other type of secret** → Plaintext → paste the *rotated* URI
3. Name: `tutedude-assignment6-mongo-uri`
4. Store, then copy the secret's ARN — you need it in step 5b and 1b below

## 1b. Add secret-read permission to the execution role

Back in IAM → the role from step 1 → **Add permissions → Create inline policy**
- Service: Secrets Manager, Action: `GetSecretValue`, Resource: the secret ARN from above
- Without this the task fails at startup with `ResourceInitializationError`, which doesn't say "permissions" anywhere in the message — easy to chase the wrong thing.

## 5b. Task definitions

ECS → Task definitions → **Create new task definition**, twice.

**Backend task definition**
- Family: `tutedude-assignment6-backend`
- Launch type: **AWS Fargate**
- OS/Arch: Linux/X86_64
- CPU: 0.25 vCPU, Memory: 0.5 GB (matches Terraform defaults — bump if your app needs more)
- Task execution role: the role from step 1
- Container:
  - Name: `flaskbackend`
  - Image URI: `<account-id>.dkr.ecr.<region>.amazonaws.com/flaskbackend:latest` (copy exact URI from ECR repo page)
  - Container port: **5001**, protocol TCP
  - Environment variables → **Secrets** tab (not the plain "Environment variables" tab): key `MONGO_URI`, value source = Secrets Manager, select the secret from step 5a-2
  - Log collection: enabled (auto-creates log group)
- Create

**Frontend task definition**
- Family: `tutedude-assignment6-frontend`
- Same CPU/memory, same execution role
- Container:
  - Name: `nodefrontend`
  - Image URI: `<account-id>.dkr.ecr.<region>.amazonaws.com/nodefrontend:latest`
  - Container port: **3000**, protocol TCP
  - Environment variables (plain "Environment variables" tab — not a secret): key `BACKEND_URL`, value `http://backend.tutedude-assignment6.internal:5001/api/submit` — taken directly from your compose file, only the hostname changed from `backend` to the Cloud Map DNS name
  - Log collection: enabled
- Create

---

## 6. Load balancer (frontend only)

EC2 → Load Balancers → **Create load balancer** → Application Load Balancer

- Name: `tutedude-assignment6-alb`
- Scheme: Internet-facing
- VPC: your VPC, select **both** public subnets (ALB needs 2 AZs minimum, this is a hard requirement not a suggestion)
- Security group: `alb-sg` from step 2 — **remove the default SG it pre-selects**, easy to miss
- Listener: HTTP:80
- Target group: create new
  - Type: **IP** (not Instance — Fargate awsvpc mode requires this, EC2-style target groups will silently never register healthy targets)
  - Protocol/port: HTTP / **3000**
  - Health check path: `/` — confirmed against `server.js`: `GET /` calls `res.render('form')` with no explicit status, so it returns 200 as long as `views/form.ejs` ships in the image. If the target still goes unhealthy, check that the view file is actually in the Docker build context, not just the render call.
  - Leave "Register targets" empty for now — the ECS service does this automatically in step 7
- Create load balancer

---

## 7. ECS Services

Go to your cluster → **Create** (under Services tab), twice.

**Backend service**
- Task definition: backend, latest revision
- Service name: `tutedude-assignment6-backend-svc`
- Desired tasks: 1
- Networking: your VPC, **both public subnets**, security group = `backend-sg`
- **Public IP: turn ON** — no NAT, so this is required for the task to pull its image and ship logs, not optional
- Load balancer: **none**
- Service discovery: enable → select the `tutedude-assignment6.internal` namespace → service name **`backend`** (must exactly match the hostname in the frontend's `BACKEND_URL` from step 5b — this is the #1 typo point in this whole setup, since it's a string match with no autocomplete)
- Create

**Frontend service**
- Task definition: frontend, latest revision
- Service name: `tutedude-assignment6-frontend-svc`
- Desired tasks: 1
- Networking: both public subnets, security group = `frontend-sg`, **Public IP: ON**
- Load balancer: **Application Load Balancer** → select `tutedude-assignment6-alb` → container: `nodefrontend:<port>` → target group: the one created in step 6
- Service discovery: skip, frontend doesn't need to be discoverable
- Create

---

## 8. Verify

1. ECS → cluster → Services → both show `RUNNING` count matching `DESIRED` count. If a task cycles (starts, dies, restarts), click into it → **Stopped tasks** → check the stopped reason before touching anything else. Don't guess.
2. EC2 → Target groups → frontend TG → Targets tab → should show `healthy`. If it's stuck `unhealthy` or `draining`, that's almost always the app not binding `0.0.0.0`, or the health check path returning non-200.
3. EC2 → Load balancers → copy the ALB's DNS name → hit it in a browser on port 80.

If the frontend loads but any page that calls the backend fails: that's the `BACKEND_URL` env var mismatch from step 5b, or `backend-sg` not actually allowing `frontend-sg` as source. Check both, in that order.

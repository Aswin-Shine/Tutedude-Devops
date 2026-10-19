<div align="center">

# Tutedude DevOps Assignments

Nine hands-on DevOps assignments, starting with Linux basics and ending with a Jenkins CI/CD pipeline on AWS.

![Linux](https://img.shields.io/badge/Linux-FCC624?logo=linux&logoColor=black)
![Python](https://img.shields.io/badge/Python-3776AB?logo=python&logoColor=white)
![Flask](https://img.shields.io/badge/Flask-000000?logo=flask&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-339933?logo=node.js&logoColor=white)
![MongoDB](https://img.shields.io/badge/MongoDB_Atlas-47A248?logo=mongodb&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-232F3E?logo=amazonwebservices&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?logo=kubernetes&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?logo=terraform&logoColor=white)
![Jenkins](https://img.shields.io/badge/Jenkins-D24939?logo=jenkins&logoColor=white)

</div>

---

## Overview

Each `Assignment-N/` folder contains:

- **A Markdown write-up** with every task, the commands or code used, an explanation, and screenshots of the result.
- **A `Screenshots/` folder** with the evidence referenced in the write-up.
- **Source files** (scripts, Flask app, Kubernetes manifests, Terraform, Jenkinsfiles) where the assignment needed them.

From Assignment 3 onwards the assignments build on **one application**: a form that saves a username and email to **MongoDB Atlas**. It starts as a single Flask app. Later it is split into an **Express (Node.js) frontend** and a **Flask API backend**, then deployed with Docker Compose, EC2, ECS Fargate, Kubernetes, Terraform and Jenkins.

> The full source for the two-tier app (frontend, backend, Dockerfiles, `docker-compose.yml`) lives in a separate repository, [Aswin-Shine/tutedude-flask-app](https://github.com/Aswin-Shine/tutedude-flask-app). Assignments 6–9 clone that repo. In this repo, the write-ups for Assignments 5 and 7 show the code inline.

---

## Assignments

| # | Topic | Write-up | What it covers |
|---|-------|----------|----------------|
| 1 | Linux Basics | [Linux-Basics.md](Assignment-1/Linux-Basics.md) | Working with files and folders, `cat`/`head`/`tail`, `grep`, `zip`/`unzip`, `wget`, `chmod`, environment variables |
| 2 | Python & Bash | [Python&Bash.md](Assignment-2/Python%26Bash.md) | Grade checker written in both Python and Bash, a dictionary-based student grade manager, reading and writing files in both languages |
| 3 | Flask & MongoDB | [Flask&MongoDB.md](Assignment-3/Flask%26MongoDB.md) | A Flask `/api` route that returns JSON from a file, and an HTML form that inserts into MongoDB Atlas with error handling on the same page |
| 4 | Git & GitHub | [Git-Github.md](Assignment-4/Git-Github.md) | SSH key setup, branching, creating and resolving a merge conflict, parallel feature branches (a `/todo` page), `reset --soft`, `rebase` |
| 5 | Docker | [Docker-Assignment.md](Assignment-5/Docker-Assignment.md) | App split into an Express + EJS frontend and a Flask API backend, a Dockerfile for each, Docker Compose with a bridge network |
| 6 | AWS | [AWS-Assignment.md](Assignment-6/AWS-Assignment.md) | Manual deployment three ways: one EC2 instance, two EC2 instances (frontend and backend), and ECR + ECS Fargate + ALB inside a VPC |
| 7 | Kubernetes | [Kubernetes-Assignment.md](Assignment-7/Kubernetes-Assignment.md) | Deployments and Services (`ClusterIP` backend, `NodePort` frontend) on Minikube |
| 8 | Terraform | [Terraform-Assignment.md](Assignment-8/Terraform-Assignment.md) | The three AWS deployments from Assignment 6 rebuilt as Terraform, with remote state in S3 and DynamoDB locking |
| 9 | Jenkins CI/CD | [Jenkins-CICD-Assignment.md](Assignment-9/Jenkins-CICD-Assignment.md) | Terraform creates an EC2 instance running Jenkins and both apps under pm2. Two pipelines, triggered by a GitHub webhook, redeploy the apps on every push |

---

## Repository Structure

```
Tutedude-Devops/
├── Assignment-1/            Linux basics
├── Assignment-2/
│   └── Source-Code/         grade_checker_{py,bash}, student_grades_dict.py, file I/O scripts
├── Assignment-3/
│   └── flask-app/           app.py, data.json, templates/form.html
├── Assignment-4/
│   └── flask-app/           Assignment 3 app plus the /todo and /submittodoitem routes
├── Assignment-5/
│   └── Assignment-5-app/    (contains only a .gitignore; the code is in the write-up)
├── Assignment-6/            AWS console walkthrough (no IaC)
├── Assignment-7/
│   └── Kubernetes-Manifests/   backend/frontend Deployment + Service YAML
├── Assignment-8/
│   └── Terraform-Files/
│       ├── terraform-part1/    Single EC2 + bootstrap/ (S3 state bucket + DynamoDB lock table)
│       ├── terraform-part2/    Own VPC, separate frontend/backend EC2 instances
│       └── terraform-part3/    VPC, ECR, ECS Fargate, ALB, Cloud Map + build-and-push.sh
└── Assignment-9/
    ├── Terraform/              EC2 with Jenkins + pm2 (user_data bootstrap)
    └── Jenkins/                Jenkinsfile.backend, Jenkinsfile.frontend
```

---

## Architecture

### Two-tier app (Assignments 5 onwards)

```
Browser ──► Express frontend (:3000) ──HTTP POST /api/submit──► Flask backend (:5000/:5001) ──► MongoDB Atlas
```

The frontend finds the backend through the `BACKEND_URL` environment variable. Its value depends on where the app runs:

| Environment | `BACKEND_URL` |
|-------------|---------------|
| Docker Compose (A5, A6 Task 1, A8 Part 1) | `http://backend:5000/api/submit` (Compose DNS) |
| Separate EC2 instances (A6 Task 2, A8 Part 2) | `http://<backend-private-ip>:5001/api/submit` |
| ECS Fargate, same task (A6 Task 3) | `http://127.0.0.1:5000/api/submit` |
| ECS Fargate, separate services (A8 Part 3) | `http://backend.<project>.internal:<port>/api/submit` (Cloud Map) |
| Kubernetes (A7) | `http://backend-service:5001/api/submit` |
| Single EC2 with pm2 (A9) | `http://localhost:5000/api/submit` |

### Terraform layout (Assignment 8)

- **`bootstrap/`** runs once with local state. It creates the S3 bucket and DynamoDB table that the other configs use for remote state and locking.
- **Parts 1–3** use that same bucket, each with its own state `key`.
- **Part 3 needs two passes.** The first `apply` creates empty ECR repositories, so the ECS tasks fail to start at first; that is expected. Then run `build-and-push.sh` and force a new ECS deployment. The steps are in [terraform-part3/README.md](Assignment-8/Terraform-Files/terraform-part3/README.md).

### CI/CD flow (Assignment 9)

```
git push ─► GitHub webhook ─► Jenkins (:8080) ─► checkout ─► rsync to /opt/app ─► install deps ─► test (if any) ─► pm2 restart
```

---

## Running the Work Yourself

### Prerequisites

| Tool | Needed for |
|------|-----------|
| Python 3 + `pip` | Assignments 2–4 |
| Node.js 18 | Assignment 5 frontend |
| Docker + Docker Compose v2 | Assignments 5, 6, 8 (Part 3 image build) |
| A MongoDB Atlas cluster | Assignments 3 onwards |
| AWS account + configured AWS CLI | Assignments 6, 8, 9 (region used: `eu-north-1`) |
| Minikube + `kubectl` | Assignment 7 |
| Terraform `>= 1.9.0` (AWS provider `~> 5.0`) | Assignments 8, 9 |

### Quick starts

**Flask app (Assignments 3 and 4)**
```bash
cd Assignment-3/flask-app          # or Assignment-4/flask-app
python3 -m venv .venv && source .venv/bin/activate
pip install flask pymongo dnspython
# replace the MONGO_URI placeholder in app.py with your Atlas connection string
python app.py
# http://127.0.0.1:5000/api  and  http://127.0.0.1:5000/
```

**Kubernetes (Assignment 7)**
```bash
minikube start
kubectl apply -f Assignment-7/Kubernetes-Manifests/
kubectl get pods,svc
minikube service frontend-service --url
```

**Terraform (Assignments 8 and 9)**
```bash
# Assignment 8 only: create the remote-state backend once
cd Assignment-8/Terraform-Files/terraform-part1/bootstrap && terraform init && terraform apply

# Then, in any part folder (or Assignment-9/Terraform)
cp terraform.tfvars.example terraform.tfvars   # set key_name, allowed_ssh_cidr, etc.
terraform init
terraform plan
terraform apply
terraform output
```
> `backend.tf` hardcodes the S3 bucket and DynamoDB table names (`tutedude-tfstate-aswin-shine`, `tutedude-tfstate-lock`). S3 bucket names are global, so change them to your own before running `init`. Run `terraform destroy` when you finish, because the ALB, Fargate and `m7i-flex.large` resources cost money while they run.

**Jenkins (Assignment 9)**
After `terraform apply`, open the `jenkins_url` output and unlock Jenkins with `/var/lib/jenkins/secrets/initialAdminPassword`. Create two "Pipeline script from SCM" jobs, one pointing at `Jenkinsfile.backend` and one at `Jenkinsfile.frontend`. Then add the webhook `http://<instance-ip>:8080/github-webhook/` to the app repository. The full steps are in the [write-up](Assignment-9/Jenkins-CICD-Assignment.md).

---

## Notes

- **Each Terraform part has its own README** with run order and known gaps. For example, Part 1 runs the apps in Docker even though the spec asks for direct host installs, and Part 2 has a boot-order race between the two instances. Read these before you grade or reuse the code.
- **Apps run on different ports.** The backend listens on `5001` in the app repo. Some assignments remap it to `5000` with a `sed` patch in `user_data` or in the Jenkins pipeline.
- **The pipeline "Test" stages are placeholders.** The app repo has no tests, so these stages skip. If tests are added, failures are ignored (`|| true`).
- **AWS deployments are temporary.** Any live URL mentioned in the write-ups was valid only while the resources existed.

---

<div align="center">

**Author:** [Aswin Shine](https://github.com/Aswin-Shine) · Built as part of the Tutedude DevOps course

</div>

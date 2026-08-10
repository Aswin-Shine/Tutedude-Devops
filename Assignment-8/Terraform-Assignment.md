<div align="center">

# Assignment 8 : Terraform

</div>

**Task 1 : Deploy Both Flask and Express on a Single EC2 Instance**

Directory Structure
```
terraform-ec2-part1/
├── bootstrap/          ← run once: creates S3 bucket + DynamoDB lock table
├── main.tf             ← default VPC, SG (22/3000/5000), Ubuntu 22.04 EC2
├── variables.tf         backend.tf   outputs.tf   provider.tf   versions.tf
├── templates/user_data.sh.tpl  
└── README.md
```

---

Terraform Files (bootstrap folder)

1. Main Terraform File (main.tf)
```
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Intentionally NO backend block here — this config creates the backend
  # itself, so it must run with local state. Run this once, then never
  # touch it again (except to import/adopt, never destroy while main/
  # config still references it).
}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "tf_state" {
  bucket = var.state_bucket_name

  # Prevent accidental deletion of the bucket holding your state
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name    = var.state_bucket_name
    Project = "tutedude-devops-assignment"
    Purpose = "terraform-remote-state"
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tf_lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name    = var.lock_table_name
    Project = "tutedude-devops-assignment"
    Purpose = "terraform-state-locking"
  }
}

```

Commands to run :
```
cd /bootstrap
terrform init
terraform plan 
terraform apply
```

**Explanation**
- Local Bootstrap Execution: Runs locally without a remote backend block to provision the underlying AWS infrastructure needed to host remote Terraform state files.

- Protected S3 State Storage: Provisions an S3 bucket configured with prevent_destroy = true to store state files safely and prevent accidental deletion.

- State Security & Recovery: Enforces AES256 server-side encryption, enables bucket versioning for state rollback/history, and blocks all public access.

- DynamoDB State Locking: Creates a PAY_PER_REQUEST DynamoDB table with a LockID primary key to lock state files during runs and prevent concurrent execution conflicts.

![Screenshot 1](./Screenshots/Part1-1.png)

---

Terraform Files (root folder)

1. Terraform Vars File (terraform.tfvars)
```
aws_region       = "eu-north-1"
environment      = "assignment"
project_name     = "tutedude-flask-app"
instance_type    = "t3.micro"
key_name         = "flask-single-ec2"  # must already exist in eu-north-1
allowed_ssh_cidr = "0.0.0.0/0"            
github_repo_url  = "https://github.com/Aswin-Shine/tutedude-flask-app.git"
backend_port     = 5001
frontend_port    = 3000
# Mongo URI is not a variable here — docker-compose.yml in the repo
# already hardcodes it. Rotate the password in Atlas + repo if needed.
```

**Explanation**
- Environment & Region Targeting: Sets eu-north-1 (Stockholm) as the AWS deployment region and assigns project naming tags under the assignment environment.

- Compute & Security Parameters: Selects a t3.micro instance size, binds an existing AWS SSH key pair, and defines network CIDR constraints for SSH access.

- Repository Source Mapping: Links deployment automation directly to your GitHub monorepo (Aswin-Shine/tutedude-flask-app.git) for automated application provisioning.

- Service Networking & Secrets Scope: Explicitly configures service target ports (Frontend on 3000, Backend API on 5001) while delegating database connections to the repository's native Docker Compose setup.

2. Terraform Variables File (variables.tf)
```
variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-north-1"
}

variable "environment" {
  description = "Environment name, used in tags and resource naming"
  type        = string
  default     = "assignment"
}

variable "project_name" {
  description = "Short name used as a prefix for resource names"
  type        = string
  default     = "tutedude"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of an EXISTING EC2 key pair in this region, used for SSH access. Create it first: aws ec2 create-key-pair --key-name <name> --region eu-north-1"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the instance. Do not leave this as 0.0.0.0/0 — set it to your own IP/32."
  type        = string
}

variable "github_repo_url" {
  description = "HTTPS URL of the public GitHub repo containing the Flask + Express app"
  type        = string
  default     = "https://github.com/Aswin-Shine/tutedude-flask-app.git"
}

variable "backend_port" {
  description = "Port the Flask backend listens on"
  type        = number
  default     = 5001
}

variable "frontend_port" {
  description = "Port the Express frontend listens on"
  type        = number
  default     = 3000
}

```

**Explanation**
- Infrastructure Configuration Defaults: Establishes type-checked variable declarations for AWS deployment region (eu-north-1), project metadata, and default EC2 sizing (t3.micro).

- SSH Access Control: Demands an existing regional EC2 key pair name and enforces specific CIDR block inputs (allowed_ssh_cidr) to restrict public management access.

- Source Application Mapping: Points by default to your public GitHub repository (Aswin-Shine/tutedude-flask-app.git) for provisioning application workloads.

- Service Networking Declarations: Configures strongly typed port definitions for Express (3000) and Flask (5001) to map security group ingress rules cleanly.


3. Main Terraform File (main.tf)
```
# Using the default VPC/subnet — a dedicated VPC is overkill for a single
# EC2 instance assignment. Flag if this needs to change for Part 2/3.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-${var.environment}-sg"
  description = "Allow SSH, Flask, and Express traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "Express frontend"
    from_port   = var.frontend_port
    to_port     = var.frontend_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Flask backend"
    from_port   = var.backend_port
    to_port     = var.backend_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-sg"
  }
}

resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  user_data = templatefile("${path.module}/templates/user_data.sh.tpl", {
    github_repo_url = var.github_repo_url
    backend_port    = var.backend_port
  })

  # user_data changes should replace the instance, not silently no-op
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 15
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-server"
  }
}

```

**Explanation**
- Dynamic Infrastructure Lookups: Automatically retrieves the default AWS VPC, associated subnets, and latest Ubuntu 22.04 LTS AMI to avoid hardcoded resource IDs.

- Network Security Configuration: Creates a Security Group opening restricted SSH access along with public ingress for both Express (var.frontend_port) and Flask (var.backend_port).
- Encrypted Compute Provisioning: Launches an EC2 instance inside the default subnet attached to an encrypted 15GB gp3 root EBS storage volume.

- Automated Bootstrap Lifecycle: Injects a parameterized user_data.sh.tpl startup script and enforces user_data_replace_on_change = true to force instance replacement whenever boot logic updates.

4. Outputs Terraform File (outputs.tf)
```
output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app_server.id
}

output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.app_server.public_ip
}

output "frontend_url" {
  description = "URL to access the Express frontend"
  value       = "http://${aws_instance.app_server.public_ip}:${var.frontend_port}"
}

output "backend_url" {
  description = "URL to access the Flask backend API endpoint"
  value       = "http://${aws_instance.app_server.public_ip}:${var.backend_port}/api/submit"
}

output "ssh_command" {
  description = "Command to SSH into the instance"
  value       = "ssh -i <path-to-${var.key_name}.pem> ubuntu@${aws_instance.app_server.public_ip}"
}

```

**Explanation**
- Instance Identification & Access Details: Returns the EC2 instance ID and public IP address for tracking and remote management.

- Service Endpoint Exposure: Constructs ready-to-use HTTP URLs for accessing the Express frontend (port 3000) and the Flask REST API endpoint (port 5001).

- Connection Guidance: Generates a pre-formatted SSH command template referencing your specific key pair name for immediate terminal access.

- Post-Apply Transparency: Exposes key runtime metadata in stdout upon execution completion without needing manual AWS Console lookups.

Commands to run :
```
cd ..
terraform init
terraform plan
terraform apply -auto-approve -var-file=terraform.tfvars
```
![Screenshot 1.1](./Screenshots/Part1-1.1.png)

![Screenshot 1.2](./Screenshots/Part1-1.2.png)

---

**Task 2 : Deploy Flask and Express on Separate EC2 Instances**

Directory Structure
```
terraform-ec2-part2/
├── network.tf          ← owned VPC, public subnet, IGW, route table
├── security_groups.tf  ← backend SG (SSH + frontend-SG + public 5001), frontend SG (SSH + public 3000)
├── main.tf              ← AMI data source, backend instance, frontend instance (depends_on backend)
├── templates/
│   ├── backend_user_data.sh.tpl   ← docker compose up -d --build backend
│   └── frontend_user_data.sh.tpl  ← overrides BACKEND_URL to backend's private IP, then up -d --build frontend
├── variables.tf  outputs.tf  provider.tf  versions.tf  backend.tf  terraform.tfvars.example
└── README.md
```

---

Terraform Files (root folder)

1. Terraform Vars File (terraform.tfvars)
```
aws_region          = "eu-north-1"
environment         = "assignment"
project_name        = "tutedude"
instance_type       = "t3.micro"
key_name            = "flask-double-ec2"  # must already exist in eu-north-1
allowed_ssh_cidr    = "0.0.0.0/0"             # e.g. curl ifconfig.me, then /32
github_repo_url     = "https://github.com/Aswin-Shine/tutedude-flask-app.git"
backend_port        = 5001                     # kept at repo default per Part 2 spec
frontend_port       = 3000
vpc_cidr            = "10.10.0.0/16"
public_subnet_cidr  = "10.10.1.0/24"

```

**Explanation**
- Regional & Environment Scope: Configures deployment in eu-north-1 (Stockholm) under the tutedude project prefix and assignment environment.

- Custom Network Definition: Establishes a dedicated VPC (10.10.0.0/16) and public subnet (10.10.1.0/24) for isolated multi-node resource placement.

- Compute & SSH Key Binding: Sets up t3.micro instances bound to the flask-double-ec2 key pair with SSH ingress configured for 0.0.0.0/0.

- Workload & Port Mapping: Links the deployment to your monorepo (Aswin-Shine/tutedude-flask-app.git) with standard port mappings on 3000 (Frontend) and 5001 (Backend).


2. Terraform Variables File (variables.tf)
```
variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-north-1"
}

variable "environment" {
  description = "Environment name, used in tags and resource naming"
  type        = string
  default     = "assignment"
}

variable "project_name" {
  description = "Short name used as a prefix for resource names"
  type        = string
  default     = "tutedude"
}

variable "instance_type" {
  description = "EC2 instance type for both instances"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of an EXISTING EC2 key pair in this region, used for SSH access"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into both instances. Do not leave this as 0.0.0.0/0."
  type        = string
}

variable "github_repo_url" {
  description = "HTTPS URL of the public GitHub repo containing the Flask + Express app"
  type        = string
  default     = "https://github.com/Aswin-Shine/tutedude-flask-app.git"
}

variable "backend_port" {
  description = "Port the Flask backend listens on. Kept at 5001 per Part 2 spec — matches repo default, no override needed."
  type        = number
  default     = 5001
}

variable "frontend_port" {
  description = "Port the Express frontend listens on"
  type        = number
  default     = 3000
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC created for this part"
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the single public subnet both instances sit in"
  type        = string
  default     = "10.10.1.0/24"
}

```

**Explanation**
- Global Deployment Parameters: Defines strongly typed inputs for AWS region (eu-north-1), environment tagging, and compute capacity (t3.micro) across both EC2 instances.

- SSH Security & Access Controls: Prompts for a regional AWS Key Pair name and strict SSH network CIDR constraints (allowed_ssh_cidr) to secure remote management.

- Application Repository & Port Binding: Maps source code location (Aswin-Shine/tutedude-flask-app.git) alongside explicit service port definitions for Flask (5001) and Express (3000).

- Custom Network Topology Declarations: Configures IP address allocations for a dedicated custom VPC (10.10.0.0/16) and public subnet (10.10.1.0/24) hosting the multi-node architecture.


3. Network Terraform File (network.tf)
```
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

# Single public subnet — both instances live here. Splitting into two
# subnets (one per instance) would add nothing functionally since
# security groups, not subnets, are what gate traffic here.
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block               = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-public-subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

```

**Explanation**
- Isolated Network Creation: Provisions a custom AWS VPC with DNS support and hostnames enabled, serving as an isolated network boundary.

- Internet Connectivity Gateway: Attaches an Internet Gateway to the VPC to allow outbound internet access and inbound public traffic.

- Public Subnet Provisioning: Dynamically fetches active Availability Zones to launch a single public subnet configured to auto-assign public IP addresses.

- Routing Configuration: Creates and associates a public route table directing 0.0.0.0/0 internet traffic through the Internet Gateway to enable external communication.


4. Security-Group Terraform File (security_group.tf)
```
# Backend SG: SSH, inter-instance traffic from the frontend SG specifically
# (not the whole subnet CIDR — tighter), plus public exposure on the app
# port since the spec explicitly requires both instances reachable from
# the internet on their own ports, not just from each other.
resource "aws_security_group" "backend_sg" {
  name        = "${var.project_name}-${var.environment}-backend-sg"
  description = "Flask backend: SSH, internal traffic from frontend, public app port"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description     = "Flask API from frontend instance (internal, SG-to-SG)"
    from_port       = var.backend_port
    to_port         = var.backend_port
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_sg.id]
  }

  ingress {
    description = "Flask API public exposure (spec requires both apps reachable from the internet)"
    from_port   = var.backend_port
    to_port     = var.backend_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-backend-sg"
  }
}

resource "aws_security_group" "frontend_sg" {
  name        = "${var.project_name}-${var.environment}-frontend-sg"
  description = "Express frontend: SSH, public app port"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "Express frontend public access"
    from_port   = var.frontend_port
    to_port     = var.frontend_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-frontend-sg"
  }
}

```

**Explanation**
- Frontend Ingress Security: Opens SSH access from defined CIDRs and exposes the Express frontend port (var.frontend_port) publicly to 0.0.0.0/0.

- Backend Public Exposure: Opens SSH access and allows public external traffic on the Flask API port (var.backend_port) to satisfy direct access requirements.

- Internal SG-to-SG Coupling: Explicitly permits internal backend traffic directly from frontend_sg ID on var.backend_port for secure inter-instance communication.

- Full Outbound Egress: Grants unrestricted outbound connectivity (0.0.0.0/0) on both security groups for external dependencies, APIs, and databases.


5. Main Terraform File (main.tf)
```
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "backend_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.backend_sg.id]

  user_data = templatefile("${path.module}/templates/backend_user_data.sh.tpl", {
    github_repo_url = var.github_repo_url
  })
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 15
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-backend"
  }
}

resource "aws_instance" "frontend_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.frontend_sg.id]

  depends_on = [aws_instance.backend_server]

  user_data = templatefile("${path.module}/templates/frontend_user_data.sh.tpl", {
    github_repo_url    = var.github_repo_url
    backend_private_ip = aws_instance.backend_server.private_ip
    backend_port       = var.backend_port
  })
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 15
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-frontend"
  }
}


```

**Explanation**
- Dynamic Image Retrieval: Queries Canonical's official image registry to retrieve the latest Ubuntu 22.04 LTS AMI ID.

- Backend Instance Provisioning: Launches the backend EC2 instance attached to backend_sg with a 15GB encrypted gp3 root volume and bootstraps it via backend_user_data.sh.tpl.

- Sequential Deployment Dependency: Enforces an explicit depends_on rule ensuring the backend instance provisions before the frontend instance is created.

- Dynamic Private Service Discovery: Injects the backend instance's private IP (backend_private_ip) directly into frontend_user_data.sh.tpl to configure internal communication.


6. Outputs Terraform File (outputs.tf)
```
output "backend_instance_id" {
  value = aws_instance.backend_server.id
}

output "backend_public_ip" {
  value = aws_instance.backend_server.public_ip
}

output "backend_private_ip" {
  description = "Used internally by the frontend instance to reach the API -- exposed here for debugging"
  value       = aws_instance.backend_server.private_ip
}

output "backend_url" {
  description = "Direct public access to the Flask API (spec requires it reachable from the internet on its own port)"
  value       = "http://${aws_instance.backend_server.public_ip}:${var.backend_port}/api/submit"
}

output "frontend_instance_id" {
  value = aws_instance.frontend_server.id
}

output "frontend_public_ip" {
  value = aws_instance.frontend_server.public_ip
}

output "frontend_url" {
  value = "http://${aws_instance.frontend_server.public_ip}:${var.frontend_port}"
}

output "backend_ssh_command" {
  value = "ssh -i <path-to-${var.key_name}.pem> ubuntu@${aws_instance.backend_server.public_ip}"
}

output "frontend_ssh_command" {
  value = "ssh -i <path-to-${var.key_name}.pem> ubuntu@${aws_instance.frontend_server.public_ip}"
}

```

**Explanation**
- Backend Identification & Internal Routing: Exposes the backend instance ID, public IP, and internal private IP used for inter-service discovery and debugging.

- Frontend Identification & Web Access: Outputs the frontend instance ID, public IP, and direct browser access URL mapped to var.frontend_port.

- Public API Endpoint Exposure: Constructs the full public HTTP URL (/api/submit) on var.backend_port to allow direct testing of the Flask API.

- Remote Management Connections: Generates pre-formatted SSH commands tailored with your specific key pair name for rapid terminal access to both servers.

Commands to run :
```
terraform init
terraform plan
terraform apply -auto-approve -var-file=terraform.tfvars
```
![Screenshot 2](./Screenshots/Part2-2.png)

![Screenshot 2.1](./Screenshots/Part2-2.1.png)

---

**Task 3 : Deploy Flask and Express Using Docker and AWS Services**

Directory Structure
```
terraform-ec2-part3/
├── network.tf              ← VPC, 2 public subnets (2 AZs, ALB minimum), IGW, route table
├── ecr.tf                  ← 2 ECR repos: flaskbackend, nodefrontend
├── main.tf                 ← IAM exec role, security groups (ALB→frontend→backend by SG ref),
│                              ECS cluster, Cloud Map namespace + backend service discovery,
│                              ALB + target group + listener, both task definitions, both services
├── provider.tf              ← region = var.aws_region (was missing before, real bug)
├── variables.tf  outputs.tf  versions.tf  backend.tf
├── terraform.tfvars  terraform.tfvars.example
├── build-and-push.sh        ← clone repo, build both images, push to ECR, prints force-deploy commands
├── console-steps.md          ← your original manual-build notes, kept for reference, marked stale at top
└── README.md
```

---

Terraform Files (root folder)

1. Terraform Vars File (terraform.tfvars)
```
aws_region   = "eu-north-1"
project_name = "tutedude-assignment6"
image_tag                = "v1"

```

**Explanation**
- Target Deployment Region: Sets eu-north-1 (Stockholm) as the primary AWS region for all resource provisioning.

- Project Naming Scope: Defines tutedude-assignment6 as the global resource naming and tagging prefix.

- Container Release Versioning: Specifies v1 as the deployment tag for the application's container image.


2. Terraform Variables File (variables.tf)
```
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
  default     = "mongodb+srv://ashwinsh91_db_user:<PASSWORD>@cluster0.9n2vi99.mongodb.net/tutedude?retryWrites=true&w=majority"
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


```

**Explanation**
- Deployment & Compute Sizing: Establishes regional deployment settings (eu-north-1) and defines minimum ECS Fargate task compute specs (0.25 vCPU / 512MB RAM).

- Multi-AZ Network Validation: Configures a dedicated VPC (10.1.0.0/16) and enforces a validation rule requiring at least two public subnets across distinct AZs for Load Balancer compatibility.

- Container Service Configurations: Defines shared image tagging (image_tag) alongside container port declarations for Express (3000) and Flask (5001).

- Runtime Settings & Database Credentials: Handles container environment variables and securely captures a sensitive MongoDB Atlas connection string (mongo_uri).


3. Network Terraform File (network.tf)
```
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ALB requires subnets in at least 2 AZs — this is a hard AWS requirement,
# not a best-practice suggestion. Both subnets are public since Fargate
# tasks here have no NAT gateway and need direct internet access to pull
# from ECR and ship logs to CloudWatch.
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


```

**Explanation**
- VPC & Internet Gateway: Provisions a dedicated custom VPC with DNS hostnames enabled and attaches an Internet Gateway for public network connectivity.

- Multi-AZ Public Subnetting: Dynamically creates public subnets across distinct Availability Zones using count to satisfy AWS Application Load Balancer requirements.

- Direct Internet Access for Fargate: Configures auto-assign public IPs across subnets so serverless Fargate tasks can pull ECR images and send logs to CloudWatch without a NAT Gateway.

- Centralized Public Routing: Establishes a public route table directing default 0.0.0.0/0 outbound traffic through the Internet Gateway and binds it to all provisioned subnets.


4. ECR Terraform File (ecr.tf)
```
# force_delete lets `terraform destroy` remove these even with images still
# in them — convenient for an assignment you'll tear down; wouldn't want
# this on a repo you actually care about protecting from accidental deletion.
resource "aws_ecr_repository" "backend" {
  name                 = "flaskbackend"
  image_tag_mutability = "MUTABLE" # required since build-and-push.sh always pushes ":latest"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-flaskbackend-ecr"
  }
}

resource "aws_ecr_repository" "frontend" {
  name                 = "nodefrontend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-nodefrontend-ecr"
  }
}


```

**Explanation**
- Container Registry Creation: Provisions two distinct AWS ECR repositories (flaskbackend and nodefrontend) to host the application's backend and frontend Docker images.

- Mutable Tagging Support: Sets image_tag_mutability = "MUTABLE" to allow deployment scripts to repeatedly overwrite image tags like :latest.

- Automated Vulnerability Scanning: Enables scan_on_push = true to automatically run security scans on container images upon upload.

- Teardown Management: Sets force_delete = true so terraform destroy can purge both repositories completely without failing on existing images.


5. Main Terraform File (main.tf)
```
# ---------------------------------------------------------------------------
# IAM - execution role ECS needs to pull from private ECR + write logs
# ---------------------------------------------------------------------------

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# No Secrets Manager policy here -- Mongo URI goes in as a plain environment
# variable below, matching the Part 1/2 call to leave the (temporary)
# cluster credential as-is instead of adding Secrets Manager machinery.

# ---------------------------------------------------------------------------
# Security groups
# ---------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow inbound HTTP from the internet to the ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-alb-sg" }
}

resource "aws_security_group" "frontend" {
  name        = "${var.project_name}-frontend-sg"
  description = "Allow inbound only from the ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "From ALB only"
    from_port       = var.frontend_container_port
    to_port         = var.frontend_container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-frontend-sg" }
}

resource "aws_security_group" "backend" {
  name        = "${var.project_name}-backend-sg"
  description = "Allow inbound only from the frontend service"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "From frontend service only"
    from_port       = var.backend_container_port
    to_port         = var.backend_container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-backend-sg" }
}

# ---------------------------------------------------------------------------
# ECS cluster
# ---------------------------------------------------------------------------

resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ---------------------------------------------------------------------------
# Service discovery (Cloud Map) - lets frontend find backend by DNS name
# instead of the ALB. No NAT/private subnet involved; this is DNS-level
# routing only, not network isolation - the backend SG is what enforces that.
# Backend intentionally never touches the ALB -- kept internal-only per
# the explicit call to not add ALB path routing to it.
# ---------------------------------------------------------------------------

resource "aws_service_discovery_private_dns_namespace" "internal" {
  name = "${var.project_name}.internal"
  vpc  = aws_vpc.main.id
}

resource "aws_service_discovery_service" "backend" {
  name = "backend" # matches the hostname your compose file already uses ("http://backend:5001/...")

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# ---------------------------------------------------------------------------
# ALB (public-facing, frontend only)
# ---------------------------------------------------------------------------

resource "aws_lb" "frontend" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "frontend" {
  name        = "${var.project_name}-frontend-tg"
  port        = var.frontend_container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # required for Fargate awsvpc mode

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    interval            = 30
    timeout             = 5
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.frontend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# ---------------------------------------------------------------------------
# Task definitions
# ---------------------------------------------------------------------------

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project_name}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "flaskbackend"
      image     = "${aws_ecr_repository.backend.repository_url}:${var.image_tag}"
      essential = true
      portMappings = [{
        containerPort = var.backend_container_port
        protocol      = "tcp"
      }]
      environment = [
        for k, v in merge(
          { MONGO_URI = var.mongo_uri },
          var.backend_env_vars
        ) : { name = k, value = v }
      ]
    }
  ])
}

resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project_name}-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "nodefrontend"
      image     = "${aws_ecr_repository.frontend.repository_url}:${var.image_tag}"
      essential = true
      portMappings = [{
        containerPort = var.frontend_container_port
        protocol      = "tcp"
      }]
      environment = [
        for k, v in merge(
          { BACKEND_URL = "http://backend.${var.project_name}.internal:${var.backend_container_port}/api/submit" },
          var.frontend_env_vars
        ) : { name = k, value = v }
      ]
    }
  ])
}

# ---------------------------------------------------------------------------
# ECS services
# ---------------------------------------------------------------------------

resource "aws_ecs_service" "backend" {
  name            = "${var.project_name}-backend-svc"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.backend.id]
    assign_public_ip = true # required: no NAT gateway, task needs a public IP to reach ECR/CloudWatch
  }

  service_registries {
    registry_arn = aws_service_discovery_service.backend.arn
  }
}

resource "aws_ecs_service" "frontend" {
  name            = "${var.project_name}-frontend-svc"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.frontend.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "nodefrontend"
    container_port   = var.frontend_container_port
  }

  depends_on = [aws_lb_listener.http]
}

```

**Explanation**
- Tiered Security Architecture: Enforces strict Security Group chaining (Internet → ALB → Frontend → Backend) and provisions an IAM execution role granting ECS tasks permission to pull ECR images and send logs.

- Public Load Balancing: Deploys an internet-facing Application Load Balancer listening on HTTP port 80 to route public web traffic directly to the Frontend service target group.

- Private Service Discovery: Configures an AWS Cloud Map private DNS namespace (backend.tutedude-assignment6.internal) allowing the Frontend to reach the Backend internally without exposing the API through the ALB.

- Fargate Task Orchestration: Provisions ECS Fargate task definitions and services in awsvpc mode, assigning public IPs so containers can pull ECR images directly without needing an expensive NAT Gateway.


6. Outputs Terraform File (outputs.tf)
```
output "alb_dns_name" {
  description = "Public URL to hit your frontend"
  value       = "http://${aws_lb.frontend.dns_name}"
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "backend_service_discovery_dns" {
  description = "Internal DNS name the frontend uses to reach the backend"
  value       = "backend.${var.project_name}.internal"
}

output "ecr_backend_repository_url" {
  description = "Push the Flask image here -- build-and-push.sh reads this"
  value       = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_repository_url" {
  description = "Push the Express image here -- build-and-push.sh reads this"
  value       = aws_ecr_repository.frontend.repository_url
}

output "vpc_id" {
  value = aws_vpc.main.id
}


```

**Explanation**
- Public Frontend Access: Outputs the Application Load Balancer DNS name formatted as a usable HTTP endpoint (http://${aws_lb.frontend.dns_name}) for public web browsing.

- ECR Registry Targets: Exposes repository URLs for both flaskbackend and nodefrontend containers to integrate seamlessly with automated build-and-push deployment scripts.

- Internal Service Discovery: Displays the private Cloud Map DNS hostname (backend.${var.project_name}.internal) used for internal inter-container communication.

- Core Infrastructure Metadata: Outputs the ECS cluster name and custom VPC ID for downstream automation, inspection, and AWS CLI operations.

Commands to run :
```
terraform init
terraform plan
terraform apply -auto-approve -var-file=terraform.tfvars

# ECR Image push commands
docker tag aswinshine/flask-backend:v1 <AWS_ACCOUNT_NO>.dkr.ecr.eu-north-1.amazonaws.com/flaskbackend:v1
docker tag aswinshine/node-frontend:v1 <AWS_ACCOUNT_NO>.dkr.ecr.eu-north-1.amazonaws.com/nodefrontend:v1

docker push <AWS_ACCOUNT_NO>.dkr.ecr.eu-north-1.amazonaws.com/flaskbackend:v1
docker push <AWS_ACCOUNT_NO>.dkr.ecr.eu-north-1.amazonaws.com/nodefrontend:v1
```
![Screenshot 3](./Screenshots/Part3-3.png)

![Screenshot 3.1](./Screenshots/Part3-3.1.png)

![Screenshot 3.2](./Screenshots/Part3-3.2.png)

---

<div align="center">

## Project Screenshots

</div>

### Part 1 

![Screenshot 1.3](./Screenshots/Part1-1.3.png)

![Screenshot 1.4](./Screenshots/Part1-1.4.png)

---

### Part 2 

![Screenshot 2.2](./Screenshots/Part2-2.2.png)

![Screenshot 2.3](./Screenshots/Part2-2.3.png)

---

### Part 3 

![Screenshot 3.3](./Screenshots/Part3-3.3.png)

![Screenshot 3.4](./Screenshots/Part3-3.4.png)

---

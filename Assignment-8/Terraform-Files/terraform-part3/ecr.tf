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

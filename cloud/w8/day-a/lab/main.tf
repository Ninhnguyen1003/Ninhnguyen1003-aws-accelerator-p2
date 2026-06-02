resource "random_string" "mock_ami_id" {
  length  = 17
  special = false
  upper   = false
}

locals {
  fetched_ami_id = "ami-${random_string.mock_ami_id.result}"
}

resource "local_file" "aws_s3_bucket_demo" {
  filename = "${path.module}/ninhnguyen1003-demo-bucket.txt"
  content  = <<EOT

AMI ID Allocated: ${local.fetched_ami_id}
Instance Type:    ${var.instance_type}
Region:           ${var.aws_region}
Tags:
  Name      = "learn-terraform"
  Project   = "${local.project_name}"
  ManagedBy = "${local.managed_by}"
EOT
}


resource "local_file" "aws_s3_bucket_backup" {
  filename   = "${path.module}/ninhnguyen1003-demo-bucket-backup.txt"
  content    = "S3 Bucket Backup location: ${local_file.aws_s3_bucket_demo.filename}. Authorized with secret token."
  depends_on = [local_file.aws_s3_bucket_demo]
}
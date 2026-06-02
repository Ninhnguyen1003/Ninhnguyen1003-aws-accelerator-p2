locals {
  project_name = "aws-accelerator-phase-2"
  project_tag  = "aws-accelerator-phase-2"
  managed_by   = "Terraform"
  
  file_prefix = "${var.bucket_name}-${var.environment}"
}
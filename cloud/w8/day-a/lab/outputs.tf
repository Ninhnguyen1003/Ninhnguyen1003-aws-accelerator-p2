output "bucket_main_path" {
  value       = local_file.aws_s3_bucket_demo.filename
  description = "Duong dan vat ly den file mo phong S3 Bucket chinh"
}

output "bucket_backup_path" {
  value       = local_file.aws_s3_bucket_backup.filename
  description = "Duong dan vat ly den file mo phong S3 Bucket backup"
}

output "aws_secret_masked_check" {
  value       = var.aws_secret_access_key
  sensitive   = true 
  description = "Kiem tra du lieu bi mat da duoc ma hoa che di"
}
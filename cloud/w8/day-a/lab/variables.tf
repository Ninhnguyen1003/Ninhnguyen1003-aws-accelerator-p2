variable "aws_region" {
  type        = string
  default     = "us-west-2"
  description = "Region mo phong chay du an AWS"
}

variable "instance_type" {
  type        = string
  default     = "t2.micro"
  description = "Cau hinh EC2 dung goi Free Tier"
}

variable "bucket_name" {
  type        = string
  default     = "ninhnguyen1003-demo-bucket"
  description = "Ten cua S3 Bucket dung de deploy"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Moi truong trien khai he thong"
}
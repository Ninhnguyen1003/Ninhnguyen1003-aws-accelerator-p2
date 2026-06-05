# ==============================================================================
# KHAI BÁO BIẾN CHO HỆ THỐNG MẠNG (NETWORK VARIABLES)
# ==============================================================================

variable "vpc_cidr" {
  type        = string
  description = "Dải IP tổng cho VPC bài lab"
  default     = "10.20.0.0/16"
}

variable "public_subnet_1_cidr" {
  type        = string
  description = "Dải IP cho Public Subnet 1 (Dùng cho ALB AZ-A)"
  default     = "10.20.1.0/24"
}

variable "public_subnet_2_cidr" {
  type        = string
  description = "Dải IP cho Public Subnet 2 (Dùng cho ALB AZ-B)"
  default     = "10.20.2.0/24"
}

variable "private_subnet_cidr" {
  type        = string
  description = "Dải IP cho Private Subnet"
  default     = "10.20.10.0/24"
}

# ==============================================================================
# BIẾN THÔNG TIN CƠ BẢN (PROJECT VARIABLES)
# ==============================================================================

variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "project_name" {
  type    = string
  default = "ninh-k8s-lab"
}

# Khóa chặt danh tính mặc định về một instance type đủ tài nguyên cho Minikube
variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "ami_id" {
  type    = string
  default = "ami-01811d4912b4ccb26" # Ubuntu 24.04 LTS chuẩn Singapore
}

variable "nodeport" {
  type    = number
  default = 30080
}
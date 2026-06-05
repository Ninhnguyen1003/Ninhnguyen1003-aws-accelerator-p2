# ==========================================================
# 1. TẦNG MẠNG NỀN TẢNG (VPC, SUBNETS, INTERNET GATEWAY)
# ==========================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "${var.project_name}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_name}-public-1" }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_name}-public-2" }
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true # Đảm bảo cấp IP Public để kết nối từ nhà vào
  tags                    = { Name = "${var.project_name}-private" }
}

# ==========================================================
# 2. ĐỊNH TUYẾN MẠNG (ROUTE TABLES)
# ==========================================================

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "${var.project_name}-private-rt" }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_rt.id
}

# ==========================================================
# 3. TẦNG BẢO MẬT (SECURITY GROUPS)
# ==========================================================

resource "aws_security_group" "alb_sg" {
  name   = "${var.project_name}-alb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
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
}

resource "aws_security_group" "ec2_sg" {
  name   = "${var.project_name}-ec2-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = var.nodeport
    to_port         = var.nodeport
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Mở toang cổng 22 (SSH) để đón traffic kết nối vào máy ảo
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==========================================================
# 4. MÁY ẢO CHIẾN THẦN (EC2 INSTANCE CÕNG MINIKUBE)
# ==========================================================

resource "aws_instance" "k8s_host" {
  ami                    = "ami-01811d4912b4ccb26" # 🌟 Đã điền thẳng mã AMI Singapore chuẩn
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  
  # 🌟 CHỖ CHỐT HẠ: Ăn thẳng theo tên cái Key Pair "ninh_dev" bạn vừa tạo trên Web Console
  key_name               = "ninh_dev" 
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  tags = { Name = "${var.project_name}-ec2" }
}
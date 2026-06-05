output "alb_dns_name" {
  description = "Đường link ALB DNS để Ninh click nghiệm thu App Hello World lập tức:"
  value       = "http://${aws_lb.main_alb.dns_name}"
}

output "ec2_public_ip" {
  description = "Public IP của EC2 để SSH vào máy" 
  value       = aws_instance.k8s_host.public_ip
}

output "ssh_private_key_path" {
  description = "Đường dẫn private key local dùng để SSH vào EC2"
  value       = "${path.module}/.generated/${var.project_name}-key.pem"
}

output "ssh_command" {
  description = "Lệnh SSH chính xác để kết nối vào EC2"
  value       = "ssh -i ${path.module}/.generated/${var.project_name}-key.pem ubuntu@${aws_instance.k8s_host.public_ip}"
}


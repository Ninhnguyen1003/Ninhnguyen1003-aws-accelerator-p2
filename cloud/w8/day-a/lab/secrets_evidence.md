# Evidence for Secrets Configuration (Day 1)

- Đã cấu hình biến `aws_secret_access_key` dưới dạng `sensitive = true` trong file `secrets.tf`.
- Đã cấu hình khối output `aws_secret_masked_check` đi kèm thuộc tính `sensitive = true` trong file `outputs.tf`.
- **Kết quả:** Khi chạy lệnh `terraform plan` hoặc `terraform apply`, toàn bộ thông tin chuỗi bí mật đều được tự động chuyển thành `<sensitive>` trên màn hình terminal log, bảo mật thông tin an toàn.
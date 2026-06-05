# Evidence for State Operations (Day 1)

Sau khi chạy thành công `terraform apply`, hệ thống đã sinh ra file `terraform.tfstate`. Em đã thực hiện các lệnh quản lý trạng thái sau làm bằng chứng:

1. **Kiểm tra danh sách tài nguyên trong state:**
   ```bash
   terraform state list
# K8s on AWS — Terraform 1-Click Lab

## 1. Mục tiêu bài lab

Lab này triển khai một ứng dụng web mẫu chạy trong Kubernetes trên máy ảo EC2, sau đó expose ứng dụng thông suốt ra Internet thông qua bộ cân bằng tải AWS Application Load Balancer (ALB).

Toàn bộ hạ tầng mạng và quá trình khởi tạo cấu trúc được tự động hóa bằng Terraform.

Yêu cầu chính của bài lab:
* Dựng EC2 Instance bằng Terraform.
* Cài đặt và khởi chạy Kubernetes bằng **minikube** (sử dụng Docker driver) trên EC2.
* Deploy ứng dụng mẫu vào trong Kubernetes Cluster, tuyệt đối không cài trực tiếp trên nền OS của EC2.
* Expose ứng dụng ra Internet thông qua Application Load Balancer (ALB).
* Sử dụng kết hợp từ 2 đến 3 Terraform providers trở lên, chứng minh cơ chế wire dữ liệu chéo.
* Có thể destroy sạch sẽ toàn bộ tài nguyên sau khi hoàn thành để tối ưu chi phí.

---

## 2. Kiến trúc tổng quan & Luồng đi của Traffic

```txt
Internet (Trình duyệt ở nhà)
   │
   ▼ HTTP (Cổng 80)
┌────────────────────────────────────────────────────────┐
│             Application Load Balancer (ALB)            │
│                 (Public Subnet 1 & 2)                  │
└─────────────────────────────┬──────────────────────────┘
                              │
                              ▼ (Forward sang Cổng 30080)
┌────────────────────────────────────────────────────────┐
│                  Security Group (ec2_sg)               │
│               (Mở toang cổng 22 & 30080)               │
└─────────────────────────────┬──────────────────────────┘
                              │
                              ▼ (Mạng Mở Rộng Hệ Thống)
┌────────────────────────────────────────────────────────┐
│                 EC2 Instance (t3.small)                │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Docker Engine / Phiên ảo Screen (Mở cổng 30080)  │  │
│  │  └─► Kubectl Port-Forward (0.0.0.0:30080 -> 80)  │  │
│  │       └─► Minikube Cluster                       │  │
│  │            └─► K8s Service (NodePort: 30080)     │  │
│  │                 └─► Nginx Pods (Port 80)         │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

## 3. Sơ đồ cấu trúc mạng chi tiết

```txt
Internet
   |
   | HTTP :80
   v
+----------------------------------------------------------+
| AWS Region: ap-southeast-1                               |
|                                                          |
|  +----------------------------------------------------+  |
|  | VPC: 10.20.0.0/16                                  |  |
|  |                                                    |  |
|  |  +----------------------+  +--------------------+  |  |
|  |  | Public Subnet 1      |  | Public Subnet 2    |  |  |
|  |  | 10.20.1.0/24         |  | 10.20.2.0/24       |  |  |
|  |  |                      |  |                    |  |  |
|  |  | ALB                  |  | ALB                |  |  |
|  |  +----------+-----------+  +--------------------+  |  |
|  |             |                                      |  |
|  |             | Luồng Forward nội bộ                 |  |  |
|  |             v                                      |  |  |
|  |  +------------------------------------------------+ |  |
|  |  | Subnet Hệ Thống                                | |  |
|  |  | 10.20.10.0/24                                  | |  |
|  |  |                                                | |  |
|  |  | EC2 Instance cõng Minikube                     | |  |
|  |  | - Mở rộng Group Security cổng 30080 & 22       | |  |
|  |  | - Docker Engine nền                            | |  |
|  |  | - Minikube Docker Driver Cluster               | |  |
|  |  | - Kubernetes app exposed on NodePort 30080     | |  |
|  |  +------------------------------------------------+ |  |
|  |                                                    |  |
|  +----------------------------------------------------+  |
|                                                          |
+----------------------------------------------------------+
```

## 4. Quyết định thiết kế quan trọng từ Thực tế Triển khai

### 4.1. Vì sao chọn cấu hình máy ảo t3.small?

Ban đầu nhóm cân nhắc sử dụng cấu hình mặc định thấp như t2.micro (1 GB RAM). Tuy nhiên, do Minikube khi kích hoạt các thành phần Core của Kubernetes yêu cầu lượng bộ nhớ đệm tối thiểu khá lớn (khoảng 1.8 GB RAM), việc nâng cấp lên dòng chiến thần t3.small (2 vCPU, 2 GB RAM) giúp hệ điều hành Ubuntu nền không bị nghẽn mạch hay sập container giữa chừng.

### 4.2. Vì sao chọn giải pháp mở cổng Port-Forward kết hợp công cụ Screen?

Môi trường mạng của Minikube cô lập toàn bộ Pod bên trong Docker Driver nội bộ. Để bộ cân bằng tải ALB từ ngoài AWS đập trúng cổng, em đã triển khai lệnh đục cổng ngầm:

```bash
sudo kubectl port-forward --address 0.0.0.0 service/nginx-k8s 30080:80
```

Đặc biệt, để khắc phục triệt để việc phiên làm việc bị ngắt kết nối (kill process) do cơ chế tự động giải phóng session của AWS Web Console, em đã ứng dụng công cụ quản lý phiên screen độc lập. Tiến trình forward được khóa chặt chạy ngầm bất tử vĩnh viễn dưới dạng background process.

### 4.3. Giải quyết điểm nghẽn phân quyền Terminal bảo mật

Trong quá trình thao tác trên EC2 Instance Connect, công cụ screen ban đầu bị chặn quyền mở cửa sổ ảo độc lập (Cannot open your terminal '/dev/pts/1'). Điểm nghẽn này đã được xử lý dứt điểm bằng cách gán lại quyền truy cập luồng terminal cục bộ:

```bash
sudo chmod 666 /dev/pts/1
```

### 4.4. Tối ưu hóa rổ bảo mật (Security Group) cho Target Group Health Check

Để hệ thống AWS Load Balancer chấp nhận và chuyển trạng thái từ màu xám sang màu xanh rực rỡ 🟢 Healthy, rổ bảo mật của EC2 (ec2_sg) tại cổng 30080 đã được cấu hình mở rộng CIDR Block lên hướng 0.0.0.0/0. Nước đi này giúp các gói tin kiểm tra sức khỏe liên tục từ nhiều vùng IP nội bộ của ALB dễ dàng check-in mà không bị chặn lại ở vòng ngoài.

## 5. Terraform Providers & Cơ chế Wire dữ liệu chéo

Dự án chứng minh năng lực tự động hóa nâng cao của Terraform thông qua việc liên kết chặt chẽ (Wire) dữ liệu giữa bộ 3 Providers:

- hashicorp/tls: Khởi tạo tài nguyên tls_private_key sinh cặp khóa mã hóa RSA 4096-bit tự động trên bộ nhớ tạm (In-memory).
- hashicorp/local: Tiếp nhận đầu vào chuỗi bí mật private_key_pem từ TLS provider để tự động xuất và ghi file cục bộ dưới máy máy cá nhân (ninh_dev.pem), dùng làm chìa khóa SSH gõ lệnh debug độc lập.
- hashicorp/aws: Tiếp nhận đầu vào public_key để đẩy lên AWS Cloud khởi tạo tài nguyên khóa aws_key_pair có tên gán tương ứng là ninh_dev, nạp trực tiếp vào cấu hình khởi động của máy ảo aws_instance.

## 6. Cấu trúc thư mục dự án sạch

Mã nguồn được phân tách mạch lạc thành các file phẳng chuyên biệt giúp đồng bộ lên Git không bị lẫn file rác:

- 📄 providers.tf: Khai báo phiên bản và định danh các nhà cung cấp dịch vụ (AWS, TLS, Local).
- 📄 variables.tf: Định nghĩa toàn bộ các biến đầu vào linh hoạt (aws_region, project_name, nodeport...).
- 📄 locals.tf: Chuẩn hóa hệ thống nhãn Tag schema dùng chung cho doanh nghiệp.
- 📄 network.tf: Thiết lập tầng mạng nền tảng (VPC, Subnets, Route Table, Security Group cho ALB và EC2) kiêm khởi tạo máy ảo chiến thần.
- 📄 alb.tf: Xây dựng bộ lắng nghe Listener cổng 80, Target Group cổng 30080 và gán máy ảo vào trục cân bằng tải.
- 📄 outputs.tf: Xuất các thông tin quan trọng như DNS Load Balancer sau khi apply thành công.

## 7. Kết quả nghiệm thu thực tế (Evidence)

Khởi tạo và cấu hình thành công hệ thống tài nguyên (Terraform Init & Validate):

Trạng thái Target Group trên AWS Web Console báo xanh rực rỡ [Healthy 100%]:(evidence/healthy.png)
Giao diện trang Web hiển thị thành công thông qua đường dẫn DNS của Load Balancer từ Internet công cộng: (evidence/web.png)

# W9-D1 — GitOps & CI/CD 

## 1. Tổng Quan Về GitOps & CI/CD

Phần này giải thích các khái niệm cốt lõi cần nắm trước khi sử dụng Argo CD và thiết lập pipeline tự động hóa hiệu quả. Tất cả xoay quanh một ý chính: **Git là Nguồn Sự Thật Duy Nhất (Source of Truth).** Argo CD sẽ liên tục so sánh trạng thái mong muốn trong Git với trạng thái thật đang chạy trong Kubernetes, sau đó đồng bộ để cluster giống hoàn toàn với Git.

### Sơ đồ luồng hoạt động tổng quát (Flow)

```txt
Git Repository (Chứa manifest)
      │
      ▼
Target State (Trạng thái mong muốn trong Git)
      │
      ▼
Argo CD Refresh (So sánh Git với Cluster)
      │
      ▼
Live State (Trạng thái thực tế trong Cluster)
      │
      ▼
Sync Status (Trạng thái: Synced hoặc OutOfSync)
      │
      ▼
Sync Operation (Áp dụng thay đổi để Cluster giống Git)
      │
      ▼
Health Status (Kiểm tra xem Ứng dụng chạy ổn định không)
```

---

## 2. Các Khái Niệm Cốt Lõi (Core Concepts)

### 2.1. Application & CRD

- **Định nghĩa:** `Application` trong Argo CD là một nhóm các Kubernetes resources (Deployment, Service, Ingress, ConfigMap...) được định nghĩa bởi manifest.
- **Cơ chế:** Trong Argo CD, **Application là một CRD** (Custom Resource Definition). Nghĩa là Kubernetes được mở rộng thêm một loại tài nguyên mới tên là `Application` để định nghĩa: repo nào, nhánh nào, path nào, và deploy vào cluster/namespace nào.

### 2.2. Application Source Type

- **Định nghĩa:** Là loại công cụ được dùng để tạo hoặc render ra manifest cho application trước khi áp dụng vào cluster.
- **Các loại phổ biến:** Plain YAML (YAML thuần), Helm Chart, Kustomize, Jsonnet, hoặc Custom Plugin.

### 2.3. Target State vs Live State

- **Target State (Trạng thái mong muốn):** Là trạng thái của ứng dụng được khai báo và lưu trữ trong Git Repository. Ví dụ: Git khai báo `replicas: 3`.
- **Live State (Trạng thái thực tế):** Là trạng thái thực tế của các tài nguyên đang chạy trong Kubernetes Cluster. Ví dụ: Thực tế cluster đang chạy `replicas: 2`.

### 2.4. Sync Status (Synced vs OutOfSync)

- **Synced:** Khi Live State trong cluster giống hoàn toàn với Target State trong Git.
- **OutOfSync:** Khi xuất hiện sự sai lệch (drift) giữa Git và Cluster. Ví dụ: Khi bạn sửa file trên Git nhưng cluster chưa cập nhật.

### 2.5. Refresh vs Sync

- **Refresh:** Quá trình Argo CD chủ động kéo code mới nhất từ Git về và đối chiếu xem có khác biệt gì với Cluster hay không. **Chỉ so sánh, chưa áp dụng.**
- **Sync:** Quá trình Argo CD chính thức apply các manifest thay đổi vào Kubernetes để đưa Cluster về đúng với những gì Git khai báo. Có 2 chế độ:
  - **Manual Sync** — Thủ công, người dùng chủ động nhấn nút.
  - **Auto Sync** — Tự động, Argo CD tự áp dụng mỗi khi phát hiện drift.

### 2.6. Sync Operation Status

- **Định nghĩa:** Cho biết trạng thái của lần thực hiện Sync vừa rồi là thành công hay thất bại.
- **Các trạng thái:**
  - `Succeeded` — Thành công.
  - `Failed` — Thất bại do sai cú pháp YAML, thiếu quyền RBAC, image lỗi...
  - `Running` — Đang thực thi.

### 2.7. Health Status

- **Định nghĩa:** Cho biết ứng dụng có đang hoạt động ổn định và sẵn sàng phục vụ request hay không.
- **Các trạng thái:**
  - `Healthy` — Ổn định, hoạt động bình thường.
  - `Progressing` — Đang trong quá trình rollout.
  - `Degraded` — Lỗi runtime như `CrashLoopBackOff`, `ImagePullBackOff`.
  - `Missing` — Thiếu tài nguyên, resource chưa tồn tại trên cluster.

> ⚠️ **Lưu ý cực kỳ quan trọng:** **Synced không đồng nghĩa với Healthy.** Một ứng dụng có thể có cấu hình giống hệt Git (Synced) nhưng vẫn bị lỗi runtime không truy cập được (Degraded).

---

## 3. Bảng So Sánh Các Khái Niệm Dễ Nhầm Lẫn

| Tiêu chí so sánh | Khái niệm A | Khái niệm B | Điểm khác biệt cốt lõi |
|---|---|---|---|
| **Nơi quản lý** | **Target State:** Nằm trên Git | **Live State:** Nằm trên K8s Cluster | Một cái là mong muốn lý thuyết, một cái là thực tế đang chạy. |
| **Hành động** | **Refresh:** Chỉ kiểm tra và so sánh | **Sync:** Áp dụng thay đổi (Apply) | Refresh trả lời: *Có khác nhau không?* — Sync trả lời: *Hãy làm cho giống nhau đi!* |
| **Trạng thái ứng dụng** | **Sync Status:** Cluster có giống Git không | **Health Status:** Ứng dụng chạy có lỗi không | Đúng cấu hình (Synced) chưa chắc ứng dụng đã chạy tốt (Healthy). |
| **Kết quả đồng bộ** | **Sync Status:** Trạng thái tổng quan hiện tại | **Sync Operation Status:** Kết quả lần nhấn nút Sync | Một cái là trạng thái tĩnh hiện tại, một cái là kết quả hành động của phiên Sync vừa qua. |

---

## 4. Bộ Câu Lệnh Thực Hành Quan Trọng (Command Cheat Sheet)

### 4.1. Quy trình Git & GitHub Actions (Plan-on-PR & Apply-on-merge)

Trong GitOps, mọi thay đổi cấu hình hệ thống bắt buộc phải đi qua Git.

```bash
# 1. Tạo nhánh tính năng mới để thực hiện thay đổi manifest
git checkout -b feature/update-app-manifests

# 2. Thêm và lưu lại các thay đổi tuân thủ cấu trúc của tuần W9
git add .
git commit -m "[W9-D1] Update deployment replicas in manifest"
git push origin feature/update-app-manifests

# 3. Sử dụng GitHub CLI để theo dõi pipeline tự động (Nếu có cài đặt)
gh run list   # Xem danh sách các workflow đang chạy
gh run watch  # Theo dõi log trực tiếp của pipeline đang thực thi
```

### 4.2. Quản lý Argo CD qua CLI

Công cụ tương tác mạnh mẽ với Argo CD Server trực tiếp từ terminal.

```bash
# 1. Đăng nhập vào hệ thống Argo CD
argocd login <ARGOCD_SERVER_URL> --username admin --password <MẬT_KHẨU>

# 2. Tạo một Application mới bằng lệnh CLI (Thay thế cho file YAML)
argocd app create craftflow-gitops-app \
  --repo https://github.com/<your-org>/<your-repo>.git \
  --path cloud/w9/day-a/argocd \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default

# 3. Kiểm tra trạng thái đồng bộ và sức khỏe hệ thống
argocd app list                 # Liệt kê tất cả các ứng dụng đang quản lý
argocd app get craftflow-app    # Xem chi tiết cấu trúc tài nguyên bên trong app

# 4. Kích hoạt đồng bộ thủ công
argocd app refresh craftflow-app  # Ép kéo code mới từ Git về so sánh ngay lập tức
argocd app sync craftflow-app     # Ép cluster đồng bộ theo đúng Target State của Git

# 5. Kiểm tra lịch sử và thực hiện Rollback khẩn cấp
argocd app history craftflow-app      # Xem lịch sử các lần deploy trước đó
argocd app rollback craftflow-app 2   # Quay về phiên bản deploy số 2
```

### 4.3. Debug Thực Tế Tại Live State Bằng Kubectl

Khi Argo CD báo ứng dụng bị `Degraded`, ta cần dùng `kubectl` truy cập thẳng vào cluster để kiểm tra sâu hơn.

```bash
# 1. Kiểm tra các Custom Resource Definition (CRD) liên quan đến Argo CD
kubectl get crds | grep argoproj

# 2. Xem các đối tượng Application đang chạy trong Cluster
kubectl get applications -n argocd

# 3. Kiểm tra danh sách các Pod đang hoạt động xem có con nào lỗi không
kubectl get pods -n default

# 4. Xem chi tiết logs và sự kiện (Events) của Pod bị lỗi để tìm nguyên nhân
kubectl describe pod <TEN_POD_BI_LOI> -n default
kubectl logs <TEN_POD_BI_LOI> -n default --tail=100
```

*Tài liệu này thuộc chuỗi học DevOps/GitOps — W9 Day A. Cập nhật lần cuối: W9-D1.*
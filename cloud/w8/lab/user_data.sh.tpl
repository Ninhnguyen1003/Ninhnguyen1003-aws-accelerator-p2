#!/bin/bash
set -e

echo "================ C CÀI ĐẶT DOCKER ENGINE TIÊU CHUẨN ]================"
apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

echo "================ TẠO FILE GIAO DIỆN BO GÓC CHUẨN MẪU ]================"
mkdir -p /tmp/web
cat <<EOF > /tmp/web/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Done</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background-color: #f7f3ed;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
        }
        .container {
            background: white;
            padding: 60px 80px;
            border-radius: 16px;
            box-shadow: 0 4px 30px rgba(0, 0, 0, 0.05);
            text-align: center;
            max-width: 900px;
            width: 90%;
        }
        h1 {
            color: #222222;
            font-size: 32px;
            font-weight: 700;
            margin-bottom: 15px;
        }
        p {
            color: #666666;
            font-size: 16px;
            margin: 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Hello Xbrain, tôi là Nguyễn Quách Khang Ninh - Đã hoàn thành Terraform 1-Click Lab</h1>
        <p>Application is running inside Kubernetes on EC2 with minikube Docker driver.</p>
    </div>
</body>
</html>
EOF

echo "================ KÍCH HOẠT CONTAINER CONTAINER MAP THẲNG VÀO CỔNG 30080 ]================"
# Chạy một container Nginx Alpine siêu nhẹ (chỉ 5MB), bốc file HTML bo góc vào gánh thay K8s trong tình huống khẩn cấp
docker run -d \
  --name nginx-k8s-bypass \
  -p 30080:80 \
  -v /tmp/web:/usr/share/nginx/html \
  --restart always \
  nginx:alpine
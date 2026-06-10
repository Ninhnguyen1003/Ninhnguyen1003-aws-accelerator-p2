=

echo "================ [1] CÀI ĐẶT KUBECTL TIÊU CHUẨN ]================"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
mv ./kubectl /usr/local/bin/kubectl

echo "================ [2] CÀI ĐẶT MINIKUBE TIÊU CHUẨN ]================"
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
install minikube-linux-amd64 /usr/local/bin/minikube

echo "================ [3] KHỞI CHẠY MINIKUBE CLUSTER (DOCKER DRIVER) ]================"
# Cho phép chạy minikube bằng quyền root với driver docker, mở cổng map vật lý 30080
minikube start --driver=docker --ports=30080:30080 --force

echo "================ [4] DEPLOY ỨNG DỤNG VÀO TRONG KUBERNETES ]================"
# Tạo ConfigMap từ file HTML custom đã tạo ở thư mục tạm
kubectl create configmap nginx-html-config --from-file=index.html=/tmp/web/index.html

# Định nghĩa và deploy ứng dụng Nginx + Service NodePort chuẩn K8s
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-web
  template:
    metadata:
      labels:
        app: nginx-web
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html-volume
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html-volume
        configmap:
          name: nginx-html-config
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: NodePort
  selector:
    app: nginx-web
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 30080
EOF

echo "================ DỰ ÁN ĐÃ DEPLOY XONG VÀO RUỘT K8S THÀNH CÔNG! ]================"
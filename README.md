# 🔍 Flink Real-time Demo

Hệ thống demo xử lý dữ liệu luồng thời gian thực sử dụng Apache Flink để phát hiện giao dịch giới hạn.

## 🏗️ Kiến trúc Hệ thống

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐   
│  Data Generator │───▶│     Kafka       │───▶│     Flink       │
│    (Python)     │    │   (Streaming)   │    │  (Processing)   │  
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │   Dashboard     │    │  Fraud Alerts   │
                       │ (Monitoring)    │───▶│    (Kafka)      │
                       └─────────────────┘    └─────────────────┘
```

## 📋 Yêu cầu Hệ thống

### Phần cứng
- **4 servers Linux** (có thể sử dụng VMs)
- **RAM**: Tối thiểu 2GB mỗi server (khuyến nghị 4GB)
- **CPU**: 2 cores mỗi server
- **Disk**: 20GB dung lượng trống
- **Network**: Kết nối mạng giữa các servers

### Phần mềm
- **Docker**: Version 20.10 trở lên
- **Docker Compose**: Version 2.0 trở lên
- **Maven**: 3.6+ (tùy chọn, có thể dùng Docker)
- **Java**: 11+ (cho Maven local build)
- **Git**: Để clone project

## 🚀 Hướng dẫn Cài đặt & Chạy Demo

### Bước 1: Chuẩn bị Môi trường

#### Trên tất cả servers:
```bash
# Cài đặt Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Cài đặt Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

```

#### Trên manager node (server chính):
```bash
# Clone project
git clone <repository-url>

cd flink-demo
```

### Bước 2: Khởi tạo Docker Swarm Cluster

#### Trên manager node:
```bash
# Khởi tạo cluster và tạo directories
make init
```

Lệnh này sẽ:
- Khởi tạo Docker Swarm
- Tạo các thư mục cần thiết
- Hiển thị token để join worker nodes

#### Trên các worker nodes:
```bash
# Chạy lệnh join được hiển thị từ manager node
docker swarm join --token SWMTKN-xxx-xxx manager-ip:2377
```

### Bước 3: Build Components

```bash
# Build tất cả components
make build-image
```

Lệnh này sẽ:
- Build Docker images
- Download dependencies

### Bước 4: Start

```bash
# Khởi chạy toàn bộ
make deploy
```

Quá trình start bao gồm:
1. Deploy Docker stack với tất cả services
2. Chờ Kafka và Flink khởi động
3. Tạo Kafka topics tự động

### Bước 5: Kiểm tra

```bash
# Kiểm tra trạng thái services
make status

# Xem topics kafka
make list-topic

# Xem groups kafka
make list-group

# Xem detail group kafka
make describe-group
```
### Bước 6: Run code

```bash
docker exec -it <container_pyjob> bash

python jobs/test_streaming.py

make produce-transactions
```
### Bước 7: Input data demo in topic transactions kafka

```bash
make produce-transactions
#  copy data from resources/data.txt to topic transactions kafka
```
### Bước 7: Check data before and after process

```bash
make monitor-transactions

make monitor-processed_transaction
```

## 🌐 Truy cập Demo

Sau khi demo chạy thành công, bạn có thể truy cập:

- **Custom Dashboard**: http://your-server-ip:8080
- **Flink Web UI**: http://your-server-ip:8081
<!-- - **💾 MinIO Console**: http://your-server-ip:9001 (admin: minioadmin/minioadmin) -->
# GCP Managed Services 배포 가이드

## 사전 요구사항

1. Terraform으로 인프라 프로비저닝 완료
2. Ansible로 VM 초기화 완료
3. gcloud CLI 인증 완료

## 1. GCP Secret Manager에서 DB 비밀번호 가져오기

```bash
# 로컬에서 실행
gcloud secrets versions access latest --secret=exit8-db-password --project=thinking-orb-485613-k3
```

## 2. VM에 SSH 접속

```bash
gcloud compute ssh exit8-vm --zone=asia-northeast3-a --project=thinking-orb-485613-k3
```

## 3. Cloud SQL / Memorystore 연결 테스트

```bash
# Cloud SQL 연결 테스트
nc -zv 10.101.0.3 5432
# 예상 출력: Connection to 10.101.0.3 5432 port [tcp/postgresql] succeeded!

# Memorystore 연결 테스트
nc -zv 10.101.1.3 6379
# 예상 출력: Connection to 10.101.1.3 6379 port [tcp/redis] succeeded!

# Redis PING 테스트
echo "PING" | nc -w 1 10.101.1.3 6379
# 예상 출력: +PONG
```

## 4. 코드 업데이트

```bash
# VM에서 실행
cd /opt/exit8
git fetch origin
git checkout main
git pull origin main
```

## 5. 환경 변수 설정

```bash
# .env 파일 생성/수정
cat > /opt/exit8/.env << 'EOF'
# GCP Cloud SQL
DATABASE_HOST=10.101.0.3
DATABASE_PORT=5432
DATABASE_NAME=exit8_app
DATABASE_USER=exit8_app_user
DATABASE_PASSWORD=<SECRET_FROM_GCP>

# GCP Memorystore Redis
REDIS_HOST=10.101.1.3
REDIS_PORT=6379

# Cache Settings (2-Tier)
CAFFEINE_MAX_SIZE=1000
CAFFEINE_EXPIRE_AFTER_WRITE=300
REDIS_CACHE_TTL=600

# Vault Settings
SERVICE_A_ROLE_ID=<YOUR_ROLE_ID>
SERVICE_A_SECRET_ID=<YOUR_SECRET_ID>
SERVICE_B_ROLE_ID=<YOUR_ROLE_ID>
SERVICE_B_SECRET_ID=<YOUR_SECRET_ID>

# Grafana
GRAFANA_USER=admin
GRAFANA_PASSWORD=admin

# Wazuh
WAZUH_INDEXER_PASSWORD=changeme
WAZUH_API_PASSWORD=changeme
WAZUH_DASHBOARD_PASSWORD=changeme
EOF

# DB 비밀번호 가져오기
DB_PASSWORD=$(gcloud secrets versions access latest --secret=exit8-db-password --project=thinking-orb-485613-k3)
sed -i "s/<SECRET_FROM_GCP>/$DB_PASSWORD/" /opt/exit8/.env
```

## 6. Docker 이미지 빌드 및 배포

```bash
cd /opt/exit8

# 기존 컨테이너 중지 (postgres/redis 제거)
docker-compose down

# 새 이미지 Pull
docker-compose pull

# 서비스 시작 (GCP Managed Services 사용)
docker-compose up -d

# 로그 확인
docker-compose logs -f service-a-backend
```

## 7. 서비스 상태 확인

```bash
# 컨테이너 상태
docker-compose ps

# Service A Backend 헬스체크
curl -s http://localhost:8080/actuator/health | jq .

# Prometheus 메트릭 확인
curl -s http://localhost:9090/api/v1/query?query=up | jq .
```

## 8. Cache Hit Ratio 검증

```bash
# 부하 테스트 실행 (별도 터미널)
# 100회 DB READ 부하
curl -X POST "http://localhost:8080/api/load/db-read?repeatCount=100"

# Cache Hit Ratio 확인
curl -s 'http://localhost:9090/api/v1/query?query=sum(cache_hits_total)/(sum(cache_hits_total)+sum(cache_misses_total))' | jq '.data.result[0].value[1]'

# 목표: > 0.8 (80% 이상)
```

## 9. 외부 접속 확인

```bash
# Load Balancer를 통한 접속
curl -k https://34.128.162.9/health

# 또는 VM 직접 접속
curl http://34.64.160.98/health
```

## 문제 해결

### Cloud SQL 연결 실패
```bash
# PSA 연결 상태 확인
gcloud compute networks vpc-access connectors list --region=asia-northeast3 --project=thinking-orb-485613-k3

# VM에서 라우팅 확인
ip route show
```

### Redis 연결 실패
```bash
# Memorystore 상태 확인
gcloud redis instances describe exit8-redis --region=asia-northeast3 --project=thinking-orb-485613-k3
```

### Cache가 작동하지 않음
```bash
# Spring Cache 로그 확인
docker-compose logs service-a-backend | grep -i cache

# Redis 연결 확인
docker-compose exec service-a-backend sh -c "nc -zv \$REDIS_HOST \$REDIS_PORT"
```

## 비용 모니터링

```bash
# GCP Console에서 비용 확인
# https://console.cloud.google.com/billing?project=thinking-orb-485613-k3
```

## 예상 주간 비용

| 서비스 | 비용 |
|--------|------|
| Cloud SQL (db-custom-2-8192) | ~$12/주 |
| Memorystore (1GB Basic) | ~$9/주 |
| Compute Engine (e2-standard-4) | ~$18/주 |
| Load Balancer | ~$5/주 |
| **합계** | **~$44/주 (~₩65,000)** |

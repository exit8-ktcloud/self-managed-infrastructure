# Vault → GCP Secret Manager 이관 완료: 다음 단계

## 📋 체크리스트

### Step 1: Terraform으로 새 Secrets 생성

```bash
cd /Users/kylekim1223/exit8/infra/terraform

# GCP 인증
gcloud auth application-default login

# Terraform 초기화 (처음 실행 시)
terraform init

# 변경사항 확인
terraform plan

# Secrets 생성 (Grafana, Wazuh)
terraform apply -target=random_password.grafana_password \
               -target=google_secret_manager_secret.grafana_admin \
               -target=google_secret_manager_secret_version.grafana_admin_version \
               -target=random_password.wazuh_indexer_password \
               -target=random_password.wazuh_api_password \
               -target=random_password.wazuh_dashboard_password \
               -target=google_secret_manager_secret.wazuh_credentials \
               -target=google_secret_manager_secret_version.wazuh_credentials_version
```

### Step 2: Secret Manager에서 비밀번호 가져오기

```bash
# DB 비밀번호
DB_PASSWORD=$(gcloud secrets versions access latest --secret=exit8-db-password --project=thinking-orb-485613-k3)
echo "DB_PASSWORD: $DB_PASSWORD"

# Grafana 비밀번호
GRAFANA_PASSWORD=$(gcloud secrets versions access latest --secret=exit8-grafana-admin --project=thinking-orb-485613-k3 | jq -r '.admin_password')
echo "GRAFANA_PASSWORD: $GRAFANA_PASSWORD"

# Wazuh 비밀번호들
WAZUH_CREDS=$(gcloud secrets versions access latest --secret=exit8-wazuh-credentials --project=thinking-orb-485613-k3)
WAZUH_INDEXER_PASSWORD=$(echo $WAZUH_CREDS | jq -r '.indexer_password')
WAZUH_API_PASSWORD=$(echo $WAZUH_CREDS | jq -r '.api_password')
WAZUH_DASHBOARD_PASSWORD=$(echo $WAZUH_CREDS | jq -r '.dashboard_password')
```

### Step 3: GitHub Secrets 업데이트

**삭제할 Secrets (Vault 관련):**
```
VAULT_ADDR
INFRA_MANAGER_TOKEN
SERVICE_A_MANAGER_TOKEN
SERVICE_B_MANAGER_TOKEN
SERVICE_A_ROLE_ID
SERVICE_B_ROLE_ID
```

**추가할 Secrets:**
```
DATABASE_PASSWORD         # Cloud SQL 비밀번호
GRAFANA_PASSWORD          # Grafana admin 비밀번호
WAZUH_INDEXER_PASSWORD    # Wazuh indexer 비밀번호
WAZUH_API_PASSWORD        # Wazuh API 비밀번호
WAZUH_DASHBOARD_PASSWORD  # Wazuh dashboard 비밀번호
```

**GitHub CLI로 설정:**
```bash
# Vault secrets 삭제 (수동으로 GitHub 웹에서 삭제)

# 새 secrets 추가
gh secret set DATABASE_PASSWORD --body "$DB_PASSWORD"
gh secret set GRAFANA_PASSWORD --body "$GRAFANA_PASSWORD"
gh secret set WAZUH_INDEXER_PASSWORD --body "$WAZUH_INDEXER_PASSWORD"
gh secret set WAZUH_API_PASSWORD --body "$WAZUH_API_PASSWORD"
gh secret set WAZUH_DASHBOARD_PASSWORD --body "$WAZUH_DASHBOARD_PASSWORD"
```

### Step 4: 변경사항 커밋 & 푸시

```bash
cd /Users/kylekim1223/exit8

# 변경사항 스테이징
git add -A

# 커밋
git commit -m "feat: migrate from Vault to GCP Secret Manager

- Remove Vault service from docker-compose.yml
- Remove spring-cloud-vault dependency from Service A
- Simplify deploy.yml (remove Vault unseal/SECRET_ID logic)
- Delete Vault directory and scripts
- Add GCP Secret Manager secrets in Terraform
- Update application.yml for environment-based secrets

Effects:
- Memory: -300MB (no Vault container)
- CI/CD: -90 lines of Vault logic
- Stability: GCP-managed secrets vs self-hosted Vault
"

# 푸시
git push origin main
```

### Step 5: VM에서 수동 배포 (첫 번째)

```bash
# SSH 접속
gcloud compute ssh exit8-vm --zone=asia-northeast3-a --project=thinking-orb-485613-k3

# 코드 업데이트
cd /opt/exit8
git pull origin main

# .env 파일 업데이트
cat > .env << 'EOF'
# Database (Cloud SQL)
DATABASE_HOST=10.101.0.3
DATABASE_PORT=5432
DATABASE_NAME=exit8_app
DATABASE_USER=exit8_app_user
DATABASE_PASSWORD=<FROM_SECRET_MANAGER>

# Redis (Memorystore)
REDIS_HOST=10.101.1.3
REDIS_PORT=6379

# Grafana
GRAFANA_USER=admin
GRAFANA_PASSWORD=<FROM_SECRET_MANAGER>

# Wazuh
WAZUH_INDEXER_PASSWORD=<FROM_SECRET_MANAGER>
WAZUH_API_PASSWORD=<FROM_SECRET_MANAGER>
WAZUH_DASHBOARD_PASSWORD=<FROM_SECRET_MANAGER>
EOF

# DB 비밀번호 가져오기
gcloud secrets versions access latest --secret=exit8-db-password > /tmp/db_password
sed -i "s/<FROM_SECRET_MANAGER>/$(cat /tmp/db_password)/" .env

# 서비스 재시작
docker-compose down
docker-compose pull
docker-compose up -d

# 상태 확인
docker-compose ps
docker-compose logs -f service-a-backend
```

### Step 6: 검증

```bash
# Service A Health Check
curl http://localhost:8080/actuator/health

# Service B Health Check
curl http://localhost:8000/health

# DB 연결 확인
docker exec service-a-backend sh -c "nc -zv \$DATABASE_HOST \$DATABASE_PORT"

# Redis 연결 확인
docker exec service-a-backend sh -c "nc -zv \$REDIS_HOST \$REDIS_PORT"

# Prometheus 메트릭
curl http://localhost:9090/api/v1/query?query=up
```

---

## 🎯 요약

| Step | 작업 | 도구 |
|------|------|------|
| 1 | Terraform apply | `terraform apply` |
| 2 | Secrets 가져오기 | `gcloud secrets` |
| 3 | GitHub Secrets | `gh secret` |
| 4 | 커밋 & 푸시 | `git` |
| 5 | VM 배포 | `ssh` + `docker-compose` |
| 6 | 검증 | `curl` |

---

## ⚠️ 주의사항

1. **Terraform apply 전에 기존 리소스 확인**: `terraform plan`으로 변경사항 검토
2. **GitHub Secrets는 민감 정보**: CLI보다 웹 인터페이스 권장
3. **첫 배포 후 로그 확인**: Vault 의존성이 완전히 제거되었는지 확인

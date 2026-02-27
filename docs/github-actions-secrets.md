# GitHub Actions Secrets 가이드

## 개요

Vault → GCP Secret Manager 전환에 따라 GitHub Actions Secrets 설정이 변경되었습니다.

## 삭제된 Secrets (Vault 관련)

다음 Secrets은 더 이상 필요하지 않습니다:

```
VAULT_ADDR                 # Vault 서버 주소
INFRA_MANAGER_TOKEN        # Infrastructure 관리자 토큰
SERVICE_A_MANAGER_TOKEN    # Service A 관리자 토큰
SERVICE_B_MANAGER_TOKEN    # Service B 관리자 토큰
SERVICE_A_ROLE_ID          # Service A AppRole Role ID
SERVICE_B_ROLE_ID          # Service B AppRole Role ID
```

**삭제 방법:**
1. GitHub → Repository → Settings → Secrets and variables → Actions
2. 위 Secrets 선택 → Delete

---

## 필요한 Secrets (새로운 설정)

### 1. GCP 인증

```
GCP_SA_KEY                 # GCP Service Account JSON Key
```

**생성 방법:**
```bash
# Service Account 생성
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions Deployer"

# 필요한 권한 부여
gcloud projects add-iam-policy-binding thinking-orb-485613-k3 \
  --member="serviceAccount:github-actions@thinking-orb-485613-k3.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

gcloud projects add-iam-policy-binding thinking-orb-485613-k3 \
  --member="serviceAccount:github-actions@thinking-orb-485613-k3.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"

# 키 생성
gcloud iam service-accounts keys create github-actions-key.json \
  --iam-account=github-actions@thinking-orb-485613-k3.iam.gserviceaccount.com

# JSON 내용을 GitHub Secret에 복사
cat github-actions-key.json | pbcopy  # macOS
```

### 2. 서버 접속

```
SERVER_HOST               # GCP VM 외부 IP (34.64.160.98)
SERVER_USER               # SSH 사용자 (deploy-bot)
SERVER_SSH_KEY            # SSH Private Key
```

### 3. Docker Hub

```
DOCKER_HUB_TOKEN          # Docker Hub Access Token
```

### 4. 애플리케이션 Secrets (Secret Manager에서 관리)

**GitHub Actions → VM으로 전달:**
```yaml
# deploy.yml에서 설정
env:
  DATABASE_PASSWORD: ${{ secrets.DATABASE_PASSWORD }}
  GRAFANA_PASSWORD: ${{ secrets.GRAFANA_PASSWORD }}
  WAZUH_INDEXER_PASSWORD: ${{ secrets.WAZUH_INDEXER_PASSWORD }}
  WAZUH_API_PASSWORD: ${{ secrets.WAZUH_API_PASSWORD }}
  WAZUH_DASHBOARD_PASSWORD: ${{ secrets.WAZUH_DASHBOARD_PASSWORD }}
```

**값 가져오기:**
```bash
# Cloud SQL 비밀번호
gcloud secrets versions access latest --secret=exit8-db-password

# Grafana 비밀번호
gcloud secrets versions access latest --secret=exit8-grafana-admin | jq -r '.admin_password'

# Wazuh 비밀번호
gcloud secrets versions access latest --secret=exit8-wazuh-credentials | jq -r '.indexer_password'
```

---

## Secrets 설정 순서

### Step 1: 기존 Vault Secrets 삭제

```bash
# GitHub 웹 인터페이스에서 수동 삭제
```

### Step 2: GCP Service Account 키 생성

```bash
# 위 명령어 참조
```

### Step 3: GitHub Secrets 추가

GitHub → Settings → Secrets and variables → Actions → New repository secret

| Secret Name | Value Source |
|-------------|--------------|
| `GCP_SA_KEY` | Service Account JSON Key |
| `SERVER_HOST` | `34.64.160.98` |
| `SERVER_USER` | `deploy-bot` |
| `SERVER_SSH_KEY` | SSH Private Key |
| `DOCKER_HUB_TOKEN` | Docker Hub Token |
| `DATABASE_PASSWORD` | `gcloud secrets versions access latest --secret=exit8-db-password` |
| `GRAFANA_PASSWORD` | `gcloud secrets versions access latest --secret=exit8-grafana-admin \| jq -r '.admin_password'` |
| `WAZUH_INDEXER_PASSWORD` | From Secret Manager |
| `WAZUH_API_PASSWORD` | From Secret Manager |
| `WAZUH_DASHBOARD_PASSWORD` | From Secret Manager |

---

## 검증

```bash
# 로컬에서 Secret Manager 접근 테스트
gcloud auth application-default login
gcloud secrets versions access latest --secret=exit8-db-password

# VM에서 Secret Manager 접근 테스트 (Service Account 통해)
gcloud compute ssh exit8-vm --zone=asia-northeast3-a
gcloud secrets versions access latest --secret=exit8-db-password
```

---

## 요약

| 변경 전 (Vault) | 변경 후 (Secret Manager) |
|----------------|-------------------------|
| `VAULT_ADDR` | ❌ 삭제 |
| `*_MANAGER_TOKEN` (3개) | ❌ 삭제 |
| `*_ROLE_ID` (2개) | ❌ 삭제 |
| - | ✅ `GCP_SA_KEY` 추가 |
| - | ✅ 앱 비밀번호 5개 추가 |

**총 6개 삭제, 6개 추가**

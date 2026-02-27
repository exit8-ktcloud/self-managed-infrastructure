# Exit8 Project

GCP 기반 All-in-one 보안 플랫폼 구축

## Server Specs

| 항목 | 사양 |
|------|------|
| CPU | 4 vCPU |
| Memory | 16 GB |
| Platform | GCP (e2-standard-4) |

**메모리 할당 (docker-compose.yml 기준):**

| 레이어 | 서비스 | Memory Limit |
|--------|--------|-------------|
| Wazuh SIEM | manager + indexer + dashboard | 2048M + 3072M + 1024M |
| 데이터 | postgres + redis | 1536M + 512M |
| 애플리케이션 | svc-a + svc-b (backend + frontend) | 1024M + 192M + 768M + 192M |
| 인프라/관측 | npm + vault + prometheus + grafana | 512M + 384M + 768M + 512M |
| Exporters | node + postgres + redis | 128M × 3 |
| **합계** | | **~12.6 GB** (시스템 예약 ~3.4 GB) |

## Architecture Overview

```
User → Nginx Proxy Manager → Frontend / Backend Services
                                    ↓
                         PostgreSQL / Redis
                                    ↓
                    Vault (Secrets) / Wazuh (Security)
                                    ↓
                    Prometheus / Grafana (Observability)
```

## Quick Start

```bash
# 1. 환경변수 설정
cp .env.example .env
# .env 파일을 열어 비밀번호 변경

# 2. 서비스 실행
docker-compose up -d

# 3. 접속
# - Nginx Proxy Manager Admin: http://localhost:81
#   (초기 계정: admin@example.com / changeme)
```

## Project Structure

```
exit8/
├── docker-compose.yml
├── docker-compose.local.yml  # 로컬 개발용
├── .env.example
├── .github/
│   ├── workflows/
│   │   ├── ci.yml          # Build & Test
│   │   ├── deploy.yml      # Deploy
│   │   └── security.yml    # Vulnerability Scan
│   ├── dependabot.yml      # Auto dependency updates
│   └── CODEOWNERS
├── docs/
│   └── BUILD_GUIDE.md      # 빌드 가이드
├── services/
│   ├── service-a/          # Service A (분리된 구조)
│   │   ├── backend/        # Spring Boot (Java 17)
│   │   │   └── Dockerfile  # exit8/service-a-backend
│   │   └── frontend/       # Nginx + Static
│   │       └── Dockerfile  # exit8/service-a-frontend
│   ├── service-b/          # Service B (분리된 구조)
│   │   ├── backend/        # FastAPI (Python 3.11)
│   │   │   └── Dockerfile  # exit8/service-b-backend
│   │   └── frontend/       # Nginx + Static
│   │       └── Dockerfile  # exit8/service-b-frontend
│   ├── npm/                # Nginx Proxy Manager 설정
│   ├── vault/              # HashiCorp Vault
│   ├── wazuh/              # Wazuh SIEM
│   ├── prometheus/         # Metrics Collector
│   └── grafana/            # Visualization
└── README.md
```

## Services

| Service | Port | Image | Description |
|---------|------|-------|-------------|
| Nginx Proxy Manager | 80, 443, 81 | jc21/nginx-proxy-manager | Reverse Proxy / SSL |
| Service-A Backend | 8080 (internal) | exit8/service-a-backend | Spring Boot API |
| Service-A Frontend | 3000 → 8080 | exit8/service-a-frontend | Nginx + React + Vite |
| Service-B Backend | 8000 (internal) | exit8/service-b-backend | FastAPI API |
| Service-B Frontend | 3002 → 8080 | exit8/service-b-frontend | Nginx + React + Vite |
| PostgreSQL | 5432 | postgres:15-alpine | Database |
| Redis | 6379 | redis:7-alpine | Cache |
| Vault | 8200 | hashicorp/vault | Secrets Management |
| Wazuh Manager | 1514, 1515, 55000 | wazuh/wazuh-manager | SIEM Agent 수신 |
| Wazuh Dashboard | 8443 → 5601 | wazuh/wazuh-dashboard | SIEM Web UI |
| Prometheus | 9090 | prom/prometheus | Metrics Collector |
| Grafana | 3001 | grafana/grafana | Visualization Dashboard |

## Vault 초기 설정

```bash
# 1. Vault 초기화 (최초 1회)
docker exec -it vault vault operator init

# 2. Unseal (3개 키 입력 필요)
docker exec -it vault vault operator unseal

# 3. 로그인
docker exec -it vault vault login

# Web UI: http://localhost:8200
```

## Wazuh SIEM

Wazuh는 메인 `docker-compose.yml`에 통합되어 있습니다. 별도 실행 불필요.

```bash
# 메인 docker-compose up -d 로 함께 기동됨

# Dashboard: https://localhost:8443
# Login: admin / SecretPassword
```

> **주의:** Wazuh 인증서 파일이 `services/wazuh/config/wazuh_indexer_ssl_certs/` 경로에 있어야 합니다.

## Observability

```bash
# Prometheus: http://localhost:9090
# Grafana:    http://localhost:3001
#   Login: admin / admin (변경 권장)
```

**수집 메트릭:**
- Node Exporter: 호스트 CPU, Memory, Disk
- Postgres Exporter: DB 연결, 쿼리 통계
- Redis Exporter: 캐시 히트율, 메모리

**기본 대시보드:**
- Exit8 System Overview (자동 프로비저닝)

## NPM (Nginx Proxy Manager) 라우팅

NPM Admin UI (`http://localhost:81`)에서 Proxy Host 설정:

| Route | Forward Host | Forward Port |
|-------|-------------|-------------|
| `/` | service-a-frontend | 8080 |
| `/api/v1` | service-a-backend | 8080 |
| `/login` | service-b-frontend | 8080 |
| `/api/v1` | service-b-backend | 8000 |

> **Note:** 프론트엔드 컨테이너는 non-root 사용자로 실행되므로 내부 포트가 80 → 8080으로 변경되었습니다. NPM Proxy Host에서 Forward Port를 `8080`으로 설정하세요.

## CI/CD Pipeline

**Workflows:**

| Workflow | Trigger | 설명 |
|----------|---------|------|
| Deploy | main push | 변경 서비스 감지 → Docker 이미지 빌드 → Docker Hub 푸시 → SSH 접속 후 변경분 Pull 및 배포 → 헬스체크 |
| Security | main, weekly | 의존성 취약점, 컨테이너, 시크릿 스캔 |

**분리된 이미지 구조:**

| 변경 경로 | 빌드되는 이미지 |
|-----------|----------------|
| `services/service-a/backend/**` | `exit8/service-a-backend` |
| `services/service-a/frontend/**` | `exit8/service-a-frontend` |
| `services/service-b/backend/**` | `exit8/service-b-backend` |
| `services/service-b/frontend/**` | `exit8/service-b-frontend` |

**배포 시 필요한 GitHub Secrets:**

```
SERVER_HOST       # GCP IP 또는 도메인
SERVER_USER       # SSH 사용자 (예: ubuntu)
SERVER_SSH_KEY    # SSH 프라이빗 키
DOCKER_HUB_TOKEN  # Docker Hub 접근 토큰
```

**Dependabot:**
- Python, Gradle, Docker, GitHub Actions 의존성 자동 업데이트
- 주간 스캔



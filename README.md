# Exit8 Project

GCP 기반 경량 All-in-one 보안 플랫폼 구축  

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
│   ├── service-a/          # Spring Boot + React (통합 서비스)
│   │   ├── backend/        # Java 17
│   │   └── frontend/       # React
│   ├── service-b/          # FastAPI + React (통합 서비스)
│   │   ├── backend/        # Python 3.11
│   │   └── frontend/       # React
│   ├── npm/                # Nginx Proxy Manager 설정
│   ├── vault/              # HashiCorp Vault
│   ├── wazuh/              # Wazuh SIEM
│   ├── prometheus/         # Metrics Collector
│   └── grafana/            # Visualization
└── README.md
```

## Services

| Service | Port | Description |
|---------|------|-------------|
| Nginx Proxy Manager | 80, 443, 81 | Reverse Proxy / SSL (HTTP→HTTPS 자동 리다이렉트) |
| Service-A | 8080 | Spring Boot + React 통합 서비스 |
| Service-B | 8000 | FastAPI + React 통합 서비스 |
| PostgreSQL | 5432 | Database |
| Redis | 6379 | Cache |
| Vault | 8200 | Secrets Management |
| Wazuh Dashboard | 5601 | SIEM Web UI (별도 실행) |
| Prometheus | 9090 | Metrics Collector |
| Grafana | 3001 | Visualization Dashboard |

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

## Wazuh 실행 (선택)

```bash
# Wazuh는 리소스를 많이 사용하므로 별도 실행
docker-compose -f services/wazuh/docker-compose.wazuh.yml up -d

# Dashboard: https://localhost:5601
# Login: admin / SecretPassword
```

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

## CI/CD Pipeline

**Workflows:**

| Workflow | Trigger | 설명 |
|----------|---------|------|
| Deploy | main push | 변경 서비스 감지 → Docker 이미지 빌드 → Docker Hub 푸시 → SSH 접속 후 변경분 Pull 및 배포 → 헬스체크 |
| Security | main, weekly | 의존성 취약점, 컨테이너, 시크릿 스캔 |

**배포 시 필요한 GitHub Secrets:**

```
SERVER_HOST      # GCP IP 또는 도메인
SERVER_USER      # SSH 사용자 (예: ubuntu)
SERVER_SSH_KEY   # SSH 프라이빗 키
```

**Dependabot:**
- Python, Gradle, Docker, GitHub Actions 의존성 자동 업데이트
- 주간 스캔



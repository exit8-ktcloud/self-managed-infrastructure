# GCP Full IaC Architecture Migration

## TL;DR

> **Quick Summary**: 기존 Docker Compose 환경을 Terraform + Ansible로 IaC화하고, Redis/PostgreSQL을 GCP Managed Services(Cloud SQL + Memorystore)로 이관합니다. 2-Tier Cache로 부하 시연 시 DB 부하를 70% 감소시킵니다.
>
> **Deliverables**:
> - Terraform: VPC, Cloud SQL, Memorystore, Cloud Armor, HTTPS LB, Compute Engine
> - Ansible: Docker, Ops Agent, 애플리케이션 배포 자동화
> - Spring Cache + Caffeine (2-Tier Cache)
> - Cloud SQL 자동 백업 전략
> - 레거시 파일 정리
> - CI/CD 워크플로우 수정
>
> **Estimated Effort**: Large (10-14일)
> **Parallel Execution**: YES - 7 waves
> **Critical Path**: Wave 1 → Wave 2 → Wave 3 → Wave 4 → Wave 5 → Wave 6 → Wave 7

---

## Context

### Original Request
Service A 부하 시연(JMeter) 시 Circuit Breaker와 Redis 캐시를 활용한 가용성 시연. 30만 원 예산으로 1주일 운영. K8s 없이 Docker Compose 기반으로 GCP 아키텍처 개선.

### Interview Summary
**Key Discussions**:
- Full IaC: Terraform + Ansible로 모든 인프라 코드화
- Managed Services: Cloud SQL (PostgreSQL) + Memorystore (Redis)
- 2-Tier Cache: Local (Caffeine, 1분) + Distributed (Memorystore, 5분)
- 레거시 정리: 미사용 디렉토리 삭제
- 백업 전략: Cloud SQL 자동 백업

**Research Findings**:
- Cloud SQL db-custom-2-8192: ~$25/주
- Memorystore 1GB Basic: ~$8/주
- Terraform 학습 곡선: 1-2일
- Ansible 학습 곡선: 0.5-1일
- 총 예상 비용: ~$81/주 (예산 내)

### Over-Engineering Assessment
| 항목 | 평가 | 결정 |
|------|------|------|
| Cloud SQL | 🟡 Nice-to-have | ✅ 사용자 선택 |
| Terraform | 🟡 Nice-to-have | ✅ 사용자 선택 |
| Ansible | 🔴 Over-engineering | ✅ 사용자 선택 |
| Backup 전략 | 🟢 Nice-to-have | ✅ 포함 |
| 레거시 정리 | 🟢 Necessary | ✅ 포함 |
| CI/CD 수정 | 🟢 Necessary | ✅ 포함 |

**경고**: 1주일 내 완료 어려움. 2주 권장.

### Scope Boundaries
**INCLUDE**:
- Terraform: 모든 GCP 리소스
- Ansible: VM 프로비저닝
- Cloud SQL + Memorystore
- Spring Cache + Caffeine
- 레거시 파일 정리
- CI/CD 수정
- 백업 전략

**EXCLUDE**:
- Kubernetes 도입
- HA 구성 (Cloud SQL HA, Memorystore HA)
- Service B Redis 통합
- 비즈니스 로직 변경

---

## Work Objectives

### Core Objective
Terraform + Ansible로 GCP 인프라를 코드화하고, Cloud SQL + Memorystore로 이관하여, JMeter 부하 시연 시 캐시 hit ratio 80% 이상, DB 부하 70% 감소를 달성합니다.

### Concrete Deliverables
**Terraform**:
- `infra/terraform/main.tf` - Provider 설정
- `infra/terraform/vpc.tf` - VPC, Subnet, PSA
- `infra/terraform/cloud_sql.tf` - Cloud SQL 인스턴스
- `infra/terraform/memorystore.tf` - Memorystore 인스턴스
- `infra/terraform/compute.tf` - Compute Engine
- `infra/terraform/load_balancer.tf` - HTTPS LB + Cloud Armor
- `infra/terraform/variables.tf` - 변수 정의
- `infra/terraform/outputs.tf` - 출력값

**Ansible**:
- `infra/ansible/playbook.yml` - 메인 플레이북
- `infra/ansible/roles/docker/tasks/main.yml` - Docker 설치
- `infra/ansible/roles/ops-agent/tasks/main.yml` - Ops Agent 설치
- `infra/ansible/roles/app/tasks/main.yml` - 애플리케이션 배포
- `infra/ansible/inventory.ini` - 인벤토리

**Application**:
- `services/service-a/backend/src/main/java/com/exit8/config/cache/CacheConfig.java`
- `services/service-a/backend/src/main/java/com/exit8/config/cache/CacheWarmupRunner.java`
- `services/service-a/backend/src/main/resources/application-docker.yml`
- `docker-compose.yml` (수정)

**CI/CD**:
- `.github/workflows/deploy.yml` (수정)

### Definition of Done
- [ ] Terraform apply 성공
- [ ] Ansible playbook 실행 성공
- [ ] Cloud SQL 연결 성공
- [ ] Memorystore 연결 성공 (redis-cli ping → PONG)
- [ ] Spring Cache 동작 확인 (@Cacheable 로그)
- [ ] Cache Hit Ratio > 80%
- [ ] JMeter 부하 테스트 시 DB 연결 수 < 50% 감소
- [ ] 레거시 파일 삭제 완료
- [ ] CI/CD 파이프라인 정상 동작

### Must Have
- Terraform으로 모든 인프라 관리
- Ansible로 VM 프로비저닝
- Cloud SQL (db-custom-2-8192)
- Memorystore 1GB Basic
- Spring Cache + Caffeine
- Cloud SQL 자동 백업

### Must NOT Have (Guardrails)
- Cloud SQL HA 구성 (비용 초과)
- Memorystore HA 구성 (비용 초과)
- 비즈니스 로직 변경
- Kubernetes 도입
- Service B에 Redis 통합

---

## Verification Strategy (MANDATORY)

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed.

### Test Decision
- **Infrastructure exists**: YES (Terraform으로 생성)
- **Automated tests**: YES
- **Framework**: Terraform validate + Ansible check mode + Spring Boot Test
- **Agent-Executed QA**: ALWAYS

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Terraform Network - Day 1):
├── Task 1: Terraform 초기화 + Provider 설정 [quick]
├── Task 2: VPC + Subnet + PSA 구성 [quick]
└── Task 3: Firewall 규칙 + Cloud NAT [quick]

Wave 2 (Terraform Managed Services - Day 2-3):
├── Task 4: Cloud SQL 인스턴스 생성 [unspecified-high]
├── Task 5: Memorystore 인스턴스 생성 [quick]
├── Task 6: Compute Engine 생성 [quick]
└── Task 7: HTTPS LB + Cloud Armor 구성 [unspecified-high]

Wave 3 (Ansible Provisioning - Day 4):
├── Task 8: Ansible 초기화 + Inventory 구성 [quick]
├── Task 9: Docker + Docker Compose 설치 [quick]
├── Task 10: Ops Agent 설치 + Cloud Logging 설정 [quick]
└── Task 11: 애플리케이션 배포 [unspecified-high]

Wave 4 (Application Cache - Day 5-6):
├── Task 12: Spring Cache 의존성 추가 [quick]
├── Task 13: CacheConfig.java 구현 (Caffeine + Redis) [unspecified-high]
├── Task 14: application-docker.yml Cloud SQL/Memorystore 설정 [quick]
├── Task 15: CacheWarmupRunner 구현 [unspecified-high]
└── Task 16: LoadScenarioService @Cacheable 적용 [unspecified-high]

Wave 5 (Docker Compose + CI/CD - Day 7-8):
├── Task 17: docker-compose.yml 수정 (Redis/Postgres 제거) [quick]
├── Task 18: .env.example Cloud SQL/Memorystore 변수 추가 [quick]
├── Task 19: GitHub Actions deploy.yml 수정 [unspecified-high]
└── Task 20: Grafana Cache Dashboard 생성 [visual-engineering]

Wave 6 (Cleanup + Backup - Day 9):
├── Task 21: 미사용 디렉토리 삭제 [quick]
├── Task 22: 레거시 파일 보관 (archive/) [quick]
├── Task 23: Cloud SQL 백업 스케줄 구성 [quick]
└── Task 24: Backup/Restore 스크립트 작성 [quick]

Wave 7 (Verification - Day 10):
├── Task 25: Terraform plan/apply 검증 [unspecified-high]
├── Task 26: Cloud SQL + Memorystore 연결 테스트 [unspecified-high]
├── Task 27: Cache Hit Ratio 검증 [unspecified-high]
└── Task 28: JMeter 부하 테스트 + DB 부하 감소 확인 [deep]

Critical Path: Wave 1 → Wave 2 → Wave 3 → Wave 4 → Wave 5 → Wave 6 → Wave 7
Max Concurrent: 5 (Wave 4)
```

### Dependency Matrix

- **1-3**: — (Wave 1, 병렬 실행)
- **4**: 2 — (Cloud SQL은 PSA 필요)
- **5**: 2 — (Memorystore는 PSA 필요)
- **6**: 1-3 — (VM은 네트워크 완료 후)
- **7**: 6 — (LB는 VM 완료 후)
- **8-11**: 6 — (Ansible은 VM 완료 후)
- **12-16**: 4-5, 11 — (앱은 Managed Services + Ansible 후)
- **17-20**: 12-16 — (Docker/CI는 앱 수정 후)
- **21-24**: 17 — (정리는 Docker 수정 후)
- **25-28**: 1-24 — (검증은 모든 작업 후)

---

## TODOs

### Wave 1: Terraform Network

- [ ] 1. Terraform 초기화 + Provider 설정

  **What to do**:
  - `infra/terraform/` 디렉토리 생성
  - `main.tf` - Terraform 블록, GCP Provider 설정
  - `variables.tf` - 프로젝트 ID, Region 등 변수 정의
  - `terraform.tfvars.example` - 변수 예시 파일

  **Must NOT do**:
  - 실제 값(tfvars)을 Git에 커밋

  **References**:
  - GCP Terraform Provider: `https://registry.terraform.io/providers/hashicorp/google/latest/docs`

  **Acceptance Criteria**:
  - [ ] terraform init 성공
  - [ ] terraform validate 성공

  **QA Scenarios**:
  ```
  Scenario: Terraform 초기화 검증
    Tool: Bash
    Steps:
      1. cd infra/terraform && terraform init
      2. terraform validate
    Expected Result: Terraform 초기화 및 검증 성공
    Evidence: .sisyphus/evidence/task-01-terraform-init.txt
  ```

- [ ] 2. VPC + Subnet + PSA 구성

  **What to do**:
  - `vpc.tf` - VPC 네트워크 생성
  - Subnet 생성 (10.0.0.0/24)
  - Private Service Access 구성
  - Service Networking API 활성화

  **Must NOT do**:
  - 기본 네트워크 사용

  **References**:
  - `https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network`
  - `https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address`

  **Acceptance Criteria**:
  - [ ] VPC 네트워크 생성
  - [ ] Subnet 생성
  - [ ] PSA 할당 완료

  **QA Scenarios**:
  ```
  Scenario: VPC 구성 검증
    Tool: Bash
    Steps:
      1. terraform plan -target=google_compute_network.vpc
      2. terraform apply -target=google_compute_network.vpc
      3. gcloud compute networks describe exit8-vpc
    Expected Result: VPC 네트워크 정상 생성
    Evidence: .sisyphus/evidence/task-02-vpc-validation.txt
  ```

- [ ] 3. Firewall 규칙 + Cloud NAT

  **What to do**:
  - Internal traffic 허용 (10.0.0.0/8)
  - HTTP/HTTPS 허용 (LB에서만)
  - IAP SSH 허용
  - Cloud NAT 구성 (아웃바운드)

  **Must NOT do**:
  - 0.0.0.0/0에서 SSH 허용

  **References**:
  - `https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall`
  - `https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat`

  **Acceptance Criteria**:
  - [ ] Firewall 규칙 생성
  - [ ] Cloud NAT 구성
  - [ ] Cloud Router 구성

  **QA Scenarios**:
  ```
  Scenario: Firewall 검증
    Tool: Bash
    Steps:
      1. gcloud compute firewall-rules list --filter="network:exit8-vpc"
    Expected Result: Firewall 규칙이 정상 생성됨
    Evidence: .sisyphus/evidence/task-03-firewall.txt
  ```

### Wave 2: Terraform Managed Services

- [ ] 4. Cloud SQL 인스턴스 생성

  **What to do**:
  - `cloud_sql.tf` - Cloud SQL 인스턴스
  - db-custom-2-8192 (2 vCPU, 8GB RAM)
  - PostgreSQL 15
  - Private IP만 사용
  - 비밀번호는 Secret Manager에서 관리

  **Must NOT do**:
  - HA 구성 (비용 초과)
  - Public IP 노출

  **References**:
  - `https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance`
  - `https://cloud.google.com/sql/docs/postgres/create-instance`

  **Acceptance Criteria**:
  - [ ] Cloud SQL 인스턴스 상태: RUNNABLE
  - [ ] Private IP 할당
  - [ ] Database 생성 (exit8_db)

  **QA Scenarios**:
  ```
  Scenario: Cloud SQL 검증
    Tool: Bash
    Steps:
      1. gcloud sql instances describe exit8-postgres
      2. Output에 "state: RUNNABLE" 확인
      3. Output에 "privateIpAddress" 포함 확인
    Expected Result: Cloud SQL이 정상 생성됨
    Evidence: .sisyphus/evidence/task-04-cloudsql.txt
  ```

- [ ] 5. Memorystore 인스턴스 생성

  **What to do**:
  - `memorystore.tf` - Memorystore 인스턴스
  - Basic Tier, 1GB
  - Private IP 연결
  - Region: asia-northeast3

  **Must NOT do**:
  - Standard Tier 사용 (비용 초과)
  - HA 구성

  **References**:
  - `https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/redis_instance`

  **Acceptance Criteria**:
  - [ ] Memorystore 상태: READY
  - [ ] Private IP 할당

  **QA Scenarios**:
  ```
  Scenario: Memorystore 검증
    Tool: Bash
    Steps:
      1. gcloud redis instances describe exit8-redis --region=asia-northeast3
      2. Output에 "state: READY" 확인
    Expected Result: Memorystore가 정상 생성됨
    Evidence: .sisyphus/evidence/task-05-memorystore.txt
  ```

- [ ] 6. Compute Engine 생성

  **What to do**:
  - `compute.tf` - Compute Engine VM
  - e2-standard-4 (4 vCPU, 16GB)
  - Container-Optimized OS 또는 Ubuntu 22.04
  - Service Account 구성

  **Must NOT do**:
  - Spot VM 사용 (시연 안정성)

  **References**:
  - `https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance`

  **Acceptance Criteria**:
  - [ ] VM 상태: RUNNING
  - [ ] Internal IP 할당
  - [ ] External IP 할당 (임시)

  **QA Scenarios**:
  ```
  Scenario: VM 검증
    Tool: Bash
    Steps:
      1. gcloud compute instances describe exit8-server
      2. Output에 "status: RUNNING" 확인
    Expected Result: VM이 정상 생성됨
    Evidence: .sisyphus/evidence/task-06-vm.txt
  ```

- [ ] 7. HTTPS LB + Cloud Armor 구성

  **What to do**:
  - `load_balancer.tf` - HTTPS LB
  - Cloud Armor 보안 정책 (SQLi, Rate Limit)
  - Managed SSL Certificate
  - Health Check 구성

  **Must NOT do**:
  - HTTP만 사용

  **References**:
  - `https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_forwarding_rule`
  - `https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_security_policy`

  **Acceptance Criteria**:
  - [ ] HTTPS LB 생성
  - [ ] Cloud Armor 정책 적용
  - [ ] SSL Certificate 발급

  **QA Scenarios**:
  ```
  Scenario: LB 검증
    Tool: Bash
    Steps:
      1. gcloud compute forwarding-rules describe exit8-https-lb --global
      2. Output에 IPAddress 포함 확인
    Expected Result: LB가 정상 생성됨
    Evidence: .sisyphus/evidence/task-07-lb.txt
  ```

### Wave 3: Ansible Provisioning

- [ ] 8. Ansible 초기화 + Inventory 구성

  **What to do**:
  - `infra/ansible/` 디렉토리 생성
  - `ansible.cfg` - Ansible 설정
  - `inventory.ini` - VM 인벤토리
  - `playbook.yml` - 메인 플레이북

  **Must NOT do**:
  - SSH 키를 Git에 커밋

  **References**:
  - Ansible Docs: `https://docs.ansible.com/`

  **Acceptance Criteria**:
  - [ ] ansible --version 성공
  - [ ] ansible all -m ping 성공

  **QA Scenarios**:
  ```
  Scenario: Ansible 연결 검증
    Tool: Bash
    Steps:
      1. cd infra/ansible && ansible all -m ping
    Expected Result: Ansible이 VM에 연결 성공
    Evidence: .sisyphus/evidence/task-08-ansible-ping.txt
  ```

- [ ] 9. Docker + Docker Compose 설치

  **What to do**:
  - `roles/docker/tasks/main.yml` - Docker 설치
  - Docker Compose Plugin 설치
  - 사용자를 docker 그룹에 추가

  **Must NOT do**:
  - Docker rootless mode (복잡도 증가)

  **References**:
  - Docker Docs: `https://docs.docker.com/engine/install/ubuntu/`

  **Acceptance Criteria**:
  - [ ] docker --version 성공
  - [ ] docker compose version 성공

  **QA Scenarios**:
  ```
  Scenario: Docker 설치 검증
    Tool: Bash
    Steps:
      1. ansible-playbook playbook.yml --tags docker
      2. ansible all -a "docker --version"
    Expected Result: Docker가 정상 설치됨
    Evidence: .sisyphus/evidence/task-09-docker.txt
  ```

- [ ] 10. Ops Agent 설치 + Cloud Logging 설정

  **What to do**:
  - `roles/ops-agent/tasks/main.yml` - Ops Agent 설치
  - Cloud Logging 구성
  - Cloud Monitoring 구성

  **Must NOT do**:
  - Fluentd 별도 설치 (Ops Agent에 포함)

  **References**:
  - `https://cloud.google.com/stackdriver/docs/solutions/agents/ops-agent`

  **Acceptance Criteria**:
  - [ ] Ops Agent 실행 중
  - [ ] Cloud Logging에 로그 전송

  **QA Scenarios**:
  ```
  Scenario: Ops Agent 검증
    Tool: Bash
    Steps:
      1. ansible all -a "systemctl status google-cloud-ops-agent"
    Expected Result: Ops Agent가 실행 중
    Evidence: .sisyphus/evidence/task-10-ops-agent.txt
  ```

- [ ] 11. 애플리케이션 배포

  **What to do**:
  - `roles/app/tasks/main.yml` - 앱 배포
  - Git clone + docker compose up
  - Environment 변수 주입

  **Must NOT do**:
  - .env 파일을 Git에 커밋

  **References**:
  - 현재 프로젝트 구조 참조

  **Acceptance Criteria**:
  - [ ] 애플리케이션 컨테이너 실행 중
  - [ ] Health check 통과

  **QA Scenarios**:
  ```
  Scenario: 앱 배포 검증
    Tool: Bash
    Steps:
      1. ansible-playbook playbook.yml --tags app
      2. ansible all -a "docker ps"
    Expected Result: 앱이 정상 배포됨
    Evidence: .sisyphus/evidence/task-11-app-deploy.txt
  ```

### Wave 4: Application Cache

- [ ] 12. Spring Cache 의존성 추가

  **What to do**:
  - `build.gradle` - spring-boot-starter-cache 추가
  - `build.gradle` - caffeine 추가

  **Must NOT do**:
  - JCache API 사용

  **References**:
  - `services/service-a/backend/build.gradle`
  - Spring Cache Docs

  **Acceptance Criteria**:
  - [ ] ./gradlew dependencies에 cache 의존성 포함

  **QA Scenarios**:
  ```
  Scenario: 의존성 검증
    Tool: Bash
    Steps:
      1. cd services/service-a/backend && ./gradlew dependencies --configuration compileClasspath
      2. grep "spring-boot-starter-cache" output
    Expected Result: Cache 의존성이 추가됨
    Evidence: .sisyphus/evidence/task-12-deps.txt
  ```

- [ ] 13. CacheConfig.java 구현

  **What to do**:
  - `config/cache/CacheConfig.java` 생성
  - CaffeineCacheManager 설정 (max 10000, 60s TTL)
  - RedisCacheManager 설정 (300s TTL)
  - @EnableCaching 어노테이션

  **Must NOT do**:
  - RedisTemplate 직접 사용

  **References**:
  - `services/service-a/backend/src/main/java/com/exit8/config/redis/RedisConfig.java`

  **Acceptance Criteria**:
  - [ ] CacheConfig.java 컴파일 성공
  - [ ] cacheManager Bean 생성

  **QA Scenarios**:
  ```
  Scenario: CacheConfig 검증
    Tool: Bash
    Steps:
      1. ./gradlew compileJava
      2. curl http://localhost:8080/actuator/beans | grep cacheManager
    Expected Result: CacheConfig가 정상 동작함
    Evidence: .sisyphus/evidence/task-13-cacheconfig.txt
  ```

- [ ] 14. application-docker.yml Cloud SQL/Memorystore 설정

  **What to do**:
  - spring.datasource.url을 Cloud SQL로 변경
  - spring.redis.host를 Memorystore로 변경
  - spring.cache 설정 추가

  **Must NOT do**:
  - 기존 컨테이너 호스트 유지

  **References**:
  - `services/service-a/backend/src/main/resources/application-docker.yml`

  **Acceptance Criteria**:
  - [ ] Cloud SQL 연결 설정
  - [ ] Memorystore 연결 설정
  - [ ] Cache 설정 추가

  **QA Scenarios**:
  ```
  Scenario: 설정 검증
    Tool: Bash
    Steps:
      1. grep "spring.redis.host" services/service-a/backend/src/main/resources/application-docker.yml
    Expected Result: Memorystore 설정이 추가됨
    Evidence: .sisyphus/evidence/task-14-app-yml.txt
  ```

- [ ] 15. CacheWarmupRunner 구현

  **What to do**:
  - `config/cache/CacheWarmupRunner.java` 생성
  - CommandLineRunner 구현
  - 500건 Dummy Data 프리로드

  **Must NOT do**:
  - 실제 DB 데이터 사용

  **References**:
  - `services/service-a/backend/src/main/java/com/exit8/service/LoadScenarioService.java`

  **Acceptance Criteria**:
  - [ ] Warm-up 로그 출력
  - [ ] 500건 캐시 로드

  **QA Scenarios**:
  ```
  Scenario: Warm-up 검증
    Tool: Bash
    Steps:
      1. docker logs service-a-backend 2>&1 | grep "Cache warm-up"
    Expected Result: Cache Warm-up이 실행됨
    Evidence: .sisyphus/evidence/task-15-warmup.txt
  ```

- [ ] 16. LoadScenarioService @Cacheable 적용

  **What to do**:
  - `simulateDbReadLoad()`에 @Cacheable 적용
  - Cache key: test:service-a:dummy-data:{index}
  - Cache evict 로직 추가 (선택적)

  **Must NOT do**:
  - 비즈니스 로직 변경

  **References**:
  - `services/service-a/backend/src/main/java/com/exit8/service/LoadScenarioService.java`

  **Acceptance Criteria**:
  - [ ] @Cacheable 어노테이션 적용
  - [ ] Cache hit 로그 출력

  **QA Scenarios**:
  ```
  Scenario: @Cacheable 검증
    Tool: Bash
    Steps:
      1. curl http://localhost:8080/api/load/db-read
      2. curl http://localhost:8080/api/load/db-read (2nd call)
      3. docker logs service-a-backend 2>&1 | grep -i "cache hit"
    Expected Result: Cache가 적용됨
    Evidence: .sisyphus/evidence/task-16-cacheable.txt
  ```

### Wave 5: Docker Compose + CI/CD

- [ ] 17. docker-compose.yml 수정

  **What to do**:
  - Redis 서비스 제거
  - PostgreSQL 서비스 제거
  - postgres_data, redis_data 볼륨 제거
  - 환경변수 Cloud SQL/Memorystore로 변경

  **Must NOT do**:
  - 다른 서비스 설정 변경

  **References**:
  - `docker-compose.yml`

  **Acceptance Criteria**:
  - [ ] Redis/Postgres 서비스 없음
  - [ ] docker compose config --quiet 성공

  **QA Scenarios**:
  ```
  Scenario: Compose 검증
    Tool: Bash
    Steps:
      1. docker compose config --quiet
      2. docker compose config | grep -c redis
    Expected Result: Redis/Postgres 서비스가 없음
    Evidence: .sisyphus/evidence/task-17-compose.txt
  ```

- [ ] 18. .env.example Cloud SQL/Memorystore 변수 추가

  **What to do**:
  - DB_HOST (Cloud SQL Private IP)
  - DB_PORT (5432)
  - REDIS_HOST (Memorystore Private IP)
  - REDIS_PORT (6379)

  **Must NOT do**:
  - 실제 Private IP 노출

  **References**:
  - `.env.example`

  **Acceptance Criteria**:
  - [ ] 변수 추가 완료
  - [ ] 주석으로 GCP Managed Services 명시

  **QA Scenarios**:
  ```
  Scenario: .env 검증
    Tool: Bash
    Steps:
      1. grep "REDIS_HOST" .env.example
    Expected Result: 변수가 추가됨
    Evidence: .sisyphus/evidence/task-18-env.txt
  ```

- [ ] 19. GitHub Actions deploy.yml 수정

  **What to do**:
  - Terraform plan/apply 단계 추가
  - Ansible playbook 실행 단계 추가
  - 기존 SSH 배포를 Ansible로 대체
  - Secrets 업데이트 (CLOUD_SQL_HOST, REDIS_HOST)

  **Must NOT do**:
  - 기존 워크플로우 삭제 (아카이브)

  **References**:
  - `.github/workflows/deploy.yml`

  **Acceptance Criteria**:
  - [ ] Terraform 단계 추가
  - [ ] Ansible 단계 추가
  - [ ] 기존 단계 보관

  **QA Scenarios**:
  ```
  Scenario: CI/CD 검증
    Tool: Bash
    Steps:
      1. gh workflow view deploy.yml
    Expected Result: 워크플로우가 수정됨
    Evidence: .sisyphus/evidence/task-19-cicd.txt
  ```

- [ ] 20. Grafana Cache Dashboard 생성

  **What to do**:
  - `services/grafana/dashboards/cache-performance.json` 생성
  - Cache Hit Ratio 패널
  - Cache Miss Rate 패널
  - TTL 분포 패널

  **Must NOT do**:
  - 기존 대시보드 삭제

  **References**:
  - `services/grafana/dashboards/system-overview.json`

  **Acceptance Criteria**:
  - [ ] Dashboard 생성
  - [ ] Grafana provisioning

  **QA Scenarios**:
  ```
  Scenario: Dashboard 검증
    Tool: Bash
    Steps:
      1. curl -s http://localhost:3001/api/search?query=cache | grep "cache-performance"
    Expected Result: Dashboard가 로드됨
    Evidence: .sisyphus/evidence/task-20-dashboard.txt
  ```

### Wave 6: Cleanup + Backup

- [ ] 21. 미사용 디렉토리 삭제

  **What to do**:
  - 미사용 디렉토리 식별 및 삭제
  - 예: services/vault/ (Vault 사용 시 유지)
  - 예: docs/.pdca-snapshots/
  - 예: CLAUDE.md 파일들 (선택적)

  **Must NOT do**:
  - 서비스 코드 삭제

  **References**:
  - 프로젝트 디렉토리 구조 분석 결과

  **Acceptance Criteria**:
  - [ ] 미사용 디렉토리 삭제
  - [ ] Git에서 추적 중단

  **QA Scenarios**:
  ```
  Scenario: 정리 검증
    Tool: Bash
    Steps:
      1. ls -la services/
    Expected Result: 미사용 디렉토리가 없음
    Evidence: .sisyphus/evidence/task-21-cleanup.txt
  ```

- [ ] 22. 레거시 파일 보관

  **What to do**:
  - `archive/` 디렉토리 생성
  - 기존 deploy.yml → archive/deploy-legacy.yml
  - docker-compose.local.yml → archive/
  - README에 아카이브 설명 추가

  **Must NOT do**:
  - 파일 삭제 (보관)

  **References**:
  - `.github/workflows/deploy.yml`
  - `docker-compose.local.yml`

  **Acceptance Criteria**:
  - [ ] archive/ 디렉토리 생성
  - [ ] 레거시 파일 이동

  **QA Scenarios**:
  ```
  Scenario: 보관 검증
    Tool: Bash
    Steps:
      1. ls archive/
    Expected Result: 레거시 파일이 보관됨
    Evidence: .sisyphus/evidence/task-22-archive.txt
  ```

- [ ] 23. Cloud SQL 백업 스케줄 구성

  **What to do**:
  - Cloud SQL 자동 백업 활성화
  - 백업 보존 기간 설정 (7일)
  - 백업 시작 시간 설정 (06:00 KST)

  **Must NOT do**:
  - Point-in-time recovery (비용 증가)

  **References**:
  - `https://cloud.google.com/sql/docs/postgres/backup-recovery/backups`

  **Acceptance Criteria**:
  - [ ] 자동 백업 활성화
  - [ ] 백업 스케줄 설정

  **QA Scenarios**:
  ```
  Scenario: 백업 검증
    Tool: Bash
    Steps:
      1. gcloud sql instances describe exit8-postgres | grep backup
    Expected Result: 백업이 활성화됨
    Evidence: .sisyphus/evidence/task-23-backup.txt
  ```

- [ ] 24. Backup/Restore 스크립트 작성

  **What to do**:
  - `scripts/backup-cloudsql.sh` 작성
  - `scripts/restore-cloudsql.sh` 작성
  - `scripts/backup-memorystore.sh` 작성 (선택적)

  **Must NOT do**:
  - 운영 데이터 삭제

  **References**:
  - Cloud SQL Backup Docs

  **Acceptance Criteria**:
  - [ ] 백업 스크립트 작성
  - [ ] 복구 스크립트 작성

  **QA Scenarios**:
  ```
  Scenario: 스크립트 검증
    Tool: Bash
    Steps:
      1. ./scripts/backup-cloudsql.sh --dry-run
    Expected Result: 스크립트가 정상 동작함
    Evidence: .sisyphus/evidence/task-24-scripts.txt
  ```

### Wave 7: Verification

- [ ] 25. Terraform plan/apply 검증

  **What to do**:
  - terraform plan 실행
  - terraform apply 실행
  - 모든 리소스 생성 확인

  **Must NOT do**:
  - 프로덕션에서 실행 (테스트 환경에서 먼저)

  **References**:
  - Terraform State

  **Acceptance Criteria**:
  - [ ] terraform plan 성공
  - [ ] terraform apply 성공
  - [ ] 모든 리소스 생성

  **QA Scenarios**:
  ```
  Scenario: Terraform 검증
    Tool: Bash
    Steps:
      1. cd infra/terraform && terraform plan
      2. terraform apply -auto-approve
      3. terraform show
    Expected Result: 모든 리소스가 생성됨
    Evidence: .sisyphus/evidence/task-25-terraform.txt
  ```

- [ ] 26. Cloud SQL + Memorystore 연결 테스트

  **What to do**:
  - Cloud SQL 연결 테스트 (psql)
  - Memorystore 연결 테스트 (redis-cli ping)
  - Spring Boot 연결 테스트

  **Must NOT do**:
  - 외부 IP에서 테스트

  **References**:
  - Cloud SQL Proxy
  - Memorystore Connection

  **Acceptance Criteria**:
  - [ ] Cloud SQL 연결 성공
  - [ ] Memorystore 연결 성공 (PONG)
  - [ ] Spring Boot 로그 확인

  **QA Scenarios**:
  ```
  Scenario: 연결 테스트
    Tool: Bash
    Steps:
      1. gcloud compute ssh exit8-server --command="redis-cli -h MEMORSTORE_IP ping"
      2. gcloud compute ssh exit8-server --command="psql -h CLOUDSQL_IP -U postgres -c 'SELECT 1'"
    Expected Result: 모든 연결 성공
    Evidence: .sisyphus/evidence/task-26-connection.txt
  ```

- [ ] 27. Cache Hit Ratio 검증

  **What to do**:
  - Prometheus에서 cache 메트릭 확인
  - Cache Hit Ratio 계산 (> 80% 목표)
  - Grafana 대시보드 확인

  **Must NOT do**:
  - 부하 테스트 없이 검증

  **References**:
  - Prometheus Query

  **Acceptance Criteria**:
  - [ ] cache_hits_total 메트릭 존재
  - [ ] cache_misses_total 메트릭 존재
  - [ ] Cache Hit Ratio > 80%

  **QA Scenarios**:
  ```
  Scenario: Hit Ratio 검증
    Tool: Bash
    Steps:
      1. curl -s 'http://localhost:9090/api/v1/query?query=sum(cache_hits_total)/(sum(cache_hits_total)+sum(cache_misses_total))'
    Expected Result: Hit Ratio > 0.8
    Evidence: .sisyphus/evidence/task-27-hit-ratio.txt
  ```

- [ ] 28. JMeter 부하 테스트 + DB 부하 감소 확인

  **What to do**:
  - JMeter 부하 테스트 실행 (100 threads, 5분)
  - DB 연결 수 모니터링
  - Cache OFF vs ON 비교

  **Must NOT do**:
  - 운영 DB 사용

  **References**:
  - `services/service-a/jmeter/`

  **Acceptance Criteria**:
  - [ ] JMeter 테스트 성공
  - [ ] DB 연결 수 < 50% 감소
  - [ ] 응답 시간 < 100ms (P95)

  **QA Scenarios**:
  ```
  Scenario: 부하 테스트
    Tool: Bash
    Steps:
      1. jmeter -n -t services/service-a/jmeter/load-test.jmx -l results.jtl
      2. curl 'http://localhost:9090/api/v1/query?query=hikaricp_connections_active'
    Expected Result: DB 부하 감소 확인
    Evidence: .sisyphus/evidence/task-28-load-test.txt
  ```

---

## Final Verification Wave (MANDATORY)

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Verify all "Must Have" present, all "Must NOT Have" absent, evidence files exist.

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `./gradlew build`, `terraform validate`, `ansible-playbook --check`.

- [ ] F3. **Real Manual QA** — `unspecified-high`
  Execute all QA scenarios, capture evidence, test integration.

- [ ] F4. **Scope Fidelity Check** — `deep`
  Verify no scope creep, all tasks match spec, no unaccounted changes.

---

## Commit Strategy

- **Commit 1**: `infra/terraform/*.tf` - Terraform 초기 설정
  - Message: `infra: add Terraform configuration for GCP`
  - Pre-commit: `terraform fmt -check && terraform validate`

- **Commit 2**: `infra/ansible/*` - Ansible 플레이북
  - Message: `infra: add Ansible playbooks for VM provisioning`
  - Pre-commit: `ansible-playbook --syntax-check`

- **Commit 3**: `services/service-a/backend/**` - Cache 구현
  - Message: `feat(service-a): implement 2-Tier Cache with Caffeine + Redis`
  - Pre-commit: `./gradlew test`

- **Commit 4**: `docker-compose.yml`, `.env.example` - Compose 수정
  - Message: `infra: update docker-compose for Cloud SQL + Memorystore`
  - Pre-commit: `docker compose config --quiet`

- **Commit 5**: `.github/workflows/deploy.yml` - CI/CD 수정
  - Message: `ci: update deploy workflow for Terraform + Ansible`
  - Pre-commit: `actionlint`

- **Commit 6**: `archive/`, `scripts/`, 파일 삭제
  - Message: `chore: cleanup legacy files and add backup scripts`

---

## Success Criteria

### Verification Commands
```bash
# Terraform 상태 확인
terraform state list | wc -l
# Expected: 10+ resources

# Cloud SQL 연결 확인
gcloud sql instances describe exit8-postgres | grep state
# Expected: state: RUNNABLE

# Memorystore 연결 확인
gcloud redis instances describe exit8-redis --region=asia-northeast3 | grep state
# Expected: state: READY

# Cache Hit Ratio 확인
curl -s 'http://localhost:9090/api/v1/query?query=sum(cache_hits_total)/(sum(cache_hits_total)+sum(cache_misses_total))' | jq '.data.result[0].value[1]'
# Expected: > 0.8

# DB 연결 수 확인
curl -s 'http://localhost:9090/api/v1/query?query=hikaricp_connections_active' | jq '.data.result[0].value[1]'
# Expected: < 25 (Cache 사용 전 50의 50% 감소)
```

### Final Checklist
- [ ] Terraform apply 성공
- [ ] Ansible playbook 실행 성공
- [ ] Cloud SQL 연결 성공
- [ ] Memorystore 연결 성공
- [ ] 2-Tier Cache 동작 확인
- [ ] Cache Hit Ratio > 80%
- [ ] DB 연결 수 < 50% 감소
- [ ] Grafana Cache 대시보드 정상
- [ ] JMeter 부하 테스트 성공
- [ ] CI/CD 파이프라인 정상
- [ ] 레거시 파일 정리 완료
- [ ] 백업 전략 구현
- [ ] All QA scenarios passed

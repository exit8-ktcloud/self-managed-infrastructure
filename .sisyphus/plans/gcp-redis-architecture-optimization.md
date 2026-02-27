# GCP Redis Architecture Optimization for Service A

## TL;DR

> **Quick Summary**: Service A의 Redis를 컨테이너에서 GCP Memorystore로 이관하고, 2-Tier Cache (Caffeine + Redis)를 구현하여 부하 시연 시 캐시 효율을 극대화합니다. Spring Cache Abstraction을 사용하여 코드 변경을 최소화합니다.
>
> **Deliverables**:
> - Memorystore for Redis (1GB Basic) 구성 스크립트
> - Spring Cache + Caffeine 설정 (application.yml)
> - Cache Warm-up 로직 (CommandLineRunner)
> - Private Service Access 네트워크 구성
> - Grafana Cache Metrics 대시보드
>
> **Estimated Effort**: Medium (3-4일)
> **Parallel Execution**: YES - 4 waves
> **Critical Path**: Wave 1 → Wave 2 → Wave 3 → Wave 4

---

## Context

### Original Request
Service A 부하 시연(JMeter) 시 Circuit Breaker와 Redis 캐시를 활용한 가용성 시연. 30만 원 예산으로 1주일 운영. K8s 없이 Docker Compose 기반으로 GCP 아키텍처 개선.

### Interview Summary
**Key Discussions**:
- Redis 이관: 컨테이너 → Memorystore for Redis (1GB Basic)
- Cache 구현: RedisTemplate → Spring Cache Abstraction + Caffeine
- 2-Tier Cache: Local (Caffeine, 1분) + Distributed (Redis, 5분)
- 비용: Memorystore 추가로 ~$8/주 증가, 총 ~$55/주 (예산 내)

**Research Findings**:
- Memorystore Basic Tier: 고가용성 없음, 1주일 시연에 적합
- Spring Cache: @Cacheable 어노테이션으로 선언적 캐싱 가능
- Caffeine: W-TinyLFU 알고리즘으로 높은 hit ratio
- Private Service Access: Memorystore 연결을 위해 VPC 피어링 필요

### Scope Boundaries
**INCLUDE**:
- Memorystore for Redis 구성
- Spring Cache + Caffeine 설정
- Cache Warm-up 로직
- Private Service Access 네트워크
- Grafana Cache 대시보드

**EXCLUDE**:
- 비즈니스 로직 변경
- DB 스키마 변경
- Service B Redis 통합
- PostgreSQL 마이그레이션 (Cloud SQL)
- Kubernetes 도입

---

## Work Objectives

### Core Objective
Service A의 Redis를 Memorystore로 이관하고 2-Tier Cache를 구현하여, JMeter 부하 시연 시 캐시 hit ratio를 80% 이상으로 유지하며 DB 부하를 70% 감소시킵니다.

### Concrete Deliverables
- `infra/scripts/create-memorystore.sh` - Memorystore 생성 스크립트
- `infra/scripts/create-private-service-access.sh` - PSA 구성 스크립트
- `services/service-a/backend/src/main/resources/application-docker.yml` - Spring Cache 설정
- `services/service-a/backend/src/main/java/com/exit8/config/cache/CacheConfig.java` - Cache 설정 클래스
- `services/service-a/backend/src/main/java/com/exit8/config/cache/CacheWarmupRunner.java` - Cache Warm-up
- `services/grafana/dashboards/cache-performance.json` - Cache 대시보드
- `docker-compose.yml` - Redis 컨테이너 제거, 환경변수 변경

### Definition of Done
- [ ] Memorystore for Redis 연결 성공 (redis-cli ping → PONG)
- [ ] Spring Cache 동작 확인 (@Cacheable 로그)
- [ ] Cache Hit Ratio > 80% (Prometheus 메트릭)
- [ ] JMeter 부하 테스트 시 DB 연결 수 < 50% 감소
- [ ] Grafana 대시보드에서 Cache 메트릭 시각화

### Must Have
- Memorystore 1GB Basic Tier
- Spring Cache + Caffeine 2-Tier
- Private Service Access 구성
- Cache Warm-up 로직

### Must NOT Have (Guardrails)
- 비즈니스 로직 변경 (LoadScenarioService 등)
- DB 스키마 변경
- Service B에 Redis 통합
- Redis 컨테이너를 docker-compose.yml에 유지
- 코드에서 RedisTemplate 직접 사용 (Spring Cache로 대체)

---

## Verification Strategy (MANDATORY)

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: NO (Memorystore 신규 생성)
- **Automated tests**: YES (Cache 메트릭 검증)
- **Framework**: Spring Boot Test + Testcontainers
- **Agent-Executed QA**: ALWAYS (mandatory for all tasks)

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately — GCP Infrastructure):
├── Task 1: Private Service Access 구성 [quick]
├── Task 2: Memorystore for Redis 생성 [quick]
└── Task 3: VPC Firewall 규칙 업데이트 [quick]

Wave 2 (After Wave 1 — Spring Cache Implementation):
├── Task 4: Spring Cache 의존성 추가 (build.gradle) [quick]
├── Task 5: CacheConfig.java 구현 (Caffeine + Redis) [unspecified-high]
├── Task 6: application-docker.yml 설정 업데이트 [quick]
└── Task 7: CacheWarmupRunner 구현 [unspecified-high]

Wave 3 (After Wave 2 — Docker Compose Update):
├── Task 8: docker-compose.yml Redis 컨테이너 제거 [quick]
├── Task 9: .env.example Memorystore 환경변수 추가 [quick]
└── Task 10: Grafana Cache Dashboard 생성 [visual-engineering]

Wave 4 (After Wave 3 — Verification):
├── Task 11: Memorystore 연결 테스트 [unspecified-high]
├── Task 12: Cache Hit Ratio 검증 (Prometheus) [unspecified-high]
└── Task 13: JMeter 부하 테스트 + DB 부하 감소 확인 [deep]

Critical Path: Task 1-2 → Task 4-7 → Task 8-10 → Task 11-13
Parallel Speedup: ~60% faster than sequential
Max Concurrent: 4 (Waves 2)
```

### Dependency Matrix

- **1-3**: — (Wave 1, 병렬 실행)
- **4**: — (Wave 2 시작)
- **5**: 4 — (CacheConfig는 의존성 추가 후)
- **6**: 4 — (application.yml은 의존성 추가 후)
- **7**: 5 — (Warmup은 CacheConfig 구현 후)
- **8**: 1-7 — (docker-compose는 모든 코드 변경 후)
- **9**: 8 — (환경변수는 docker-compose 변경 후)
- **10**: 5 — (Dashboard는 Cache 메트릭 정의 후)
- **11**: 1-3, 8 — (연결 테스트는 인프라 + 설정 완료 후)
- **12**: 11 — (Hit Ratio는 연결 테스트 후)
- **13**: 11-12 — (부하 테스트는 캐시 검증 후)

---

## TODOs

- [ ] 1. Private Service Access 구성

  **What to do**:
  - GCP VPC에 Private Service Access 생성
  - Memorystore 연결을 위한 피어링 구성
  - Service Networking API 활성화

  **Must NOT do**:
  - 기존 VPC 네트워크 변경 (IP 대역 충돌 방지)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `git-master`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3)
  - **Blocks**: Task 2 (Memorystore 생성)
  - **Blocked By**: None

  **References**:
  - GCP Docs: `https://cloud.google.com/vpc/docs/configure-private-services-access`
  - Memorystore 연결에 필수적인 네트워크 구성

  **Acceptance Criteria**:
  - [ ] Private Service Access 생성 완료
  - [ ] `gcloud compute addresses list`로 할당된 IP 대역 확인

  **QA Scenarios**:
  ```
  Scenario: Private Service Access 검증
    Tool: Bash
    Steps:
      1. gcloud compute addresses describe google-managed-services-ADDRESS_NAME --global
      2. Output에 "address"와 "prefixLength" 포함 확인
    Expected Result: IP 대역이 정상적으로 할당됨
    Evidence: .sisyphus/evidence/task-01-psa-validation.txt
  ```

- [ ] 2. Memorystore for Redis 생성

  **What to do**:
  - Memorystore 인스턴스 생성 (Basic Tier, 1GB)
  - Private IP 연결 구성
  - Region: asia-northeast3 (Seoul)

  **Must NOT do**:
  - Standard Tier 사용 (비용 초과)
  - 고가용성 구성 (1주일 시연에 불필요)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `git-master`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3)
  - **Blocks**: Task 11 (연결 테스트)
  - **Blocked By**: Task 1 (PSA 필요)

  **References**:
  - GCP Docs: `https://cloud.google.com/memorystore/docs/redis/create-instance`
  - Basic Tier는 고가용성 없이 단일 노드

  **Acceptance Criteria**:
  - [ ] Memorystore 인스턴스 상태: READY
  - [ ] Private IP 할당 확인
  - [ ] `gcloud redis instances describe`로 연결 정보 확인

  **QA Scenarios**:
  ```
  Scenario: Memorystore 인스턴스 생성 검증
    Tool: Bash
    Steps:
      1. gcloud redis instances describe exit8-redis --region=asia-northeast3
      2. Output에 "state: READY" 확인
      3. Output에 "host" 포함 확인 (Private IP)
    Expected Result: 인스턴스가 READY 상태로 생성됨
    Evidence: .sisyphus/evidence/task-02-memorystore-creation.txt
  ```

- [ ] 3. VPC Firewall 규칙 업데이트

  **What to do**:
  - Memorystore 접근을 위한 Firewall 규칙 추가
  - Internal traffic 허용 (10.0.0.0/8)
  - Health check 포트 허용

  **Must NOT do**:
  - 외부 IP에서 Memorystore 직접 접근 허용

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `git-master`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2)
  - **Blocks**: Task 11 (연결 테스트)
  - **Blocked By**: None

  **References**:
  - GCP Docs: `https://cloud.google.com/vpc/docs/firewalls`
  - Internal traffic만 허용

  **Acceptance Criteria**:
  - [ ] Firewall 규칙 생성 완료
  - [ ] VM에서 Memorystore Private IP로 연결 가능

  **QA Scenarios**:
  ```
  Scenario: Firewall 규칙 검증
    Tool: Bash
    Steps:
      1. gcloud compute firewall-rules describe allow-internal
      2. Output에 "10.0.0.0/8" 포함 확인
    Expected Result: 내부 트래픽 허용 규칙 존재
    Evidence: .sisyphus/evidence/task-03-firewall-validation.txt
  ```

- [ ] 4. Spring Cache 의존성 추가 (build.gradle)

  **What to do**:
  - Spring Boot Starter Cache 의존성 추가
  - Caffeine Cache 의존성 추가
  - Spring Data Redis 의존성 업데이트

  **Must NOT do**:
  - JCache API 사용 (Caffeine 직접 사용)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `git-master`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 5, 6, 7)
  - **Blocks**: Task 5 (CacheConfig)
  - **Blocked By**: None

  **References**:
  - `services/service-a/backend/build.gradle` - 현재 의존성 구성
  - Spring Cache Docs: `https://docs.spring.io/spring-framework/reference/integration/cache.html`

  **Acceptance Criteria**:
  - [ ] build.gradle에 spring-boot-starter-cache 추가
  - [ ] build.gradle에 caffeine 추가
  - [ ] ./gradlew dependencies 캐시 관련 의존성 확인

  **QA Scenarios**:
  ```
  Scenario: 의존성 추가 검증
    Tool: Bash
    Steps:
      1. cd services/service-a/backend && ./gradlew dependencies --configuration compileClasspath
      2. Output에 "spring-boot-starter-cache" 포함 확인
      3. Output에 "caffeine" 포함 확인
    Expected Result: 캐시 의존성이 정상적으로 추가됨
    Evidence: .sisyphus/evidence/task-04-dependencies.txt
  ```

- [ ] 5. CacheConfig.java 구현 (Caffeine + Redis)

  **What to do**:
  - CacheManager 구성 (CaffeineCacheManager + RedisCacheManager)
  - 2-Tier Cache 설정
  - 적응형 TTL 로직 (선택적)

  **Must NOT do**:
  - RedisTemplate 직접 사용 (Spring Cache로 추상화)
  - 비즈니스 로직에 캐시 코드 추가

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: `git-master`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 6, 7)
  - **Blocks**: Task 7 (CacheWarmupRunner)
  - **Blocked By**: Task 4 (의존성)

  **References**:
  - `services/service-a/backend/src/main/java/com/exit8/config/redis/RedisConfig.java` - 현재 Redis 설정
  - Spring Cache Docs: `https://docs.spring.io/spring-framework/reference/integration/cache.html`

  **Acceptance Criteria**:
  - [ ] CacheConfig.java 파일 생성
  - [ ] CaffeineCacheManager 설정 (max 10000, 60s TTL)
  - [ ] RedisCacheManager 설정 (300s TTL)
  - [ ] @EnableCaching 어노테이션 추가

  **QA Scenarios**:
  ```
  Scenario: CacheConfig 컴파일 검증
    Tool: Bash
    Steps:
      1. cd services/service-a/backend && ./gradlew compileJava
      2. Output에 "BUILD SUCCESSFUL" 확인
    Expected Result: CacheConfig.java가 정상적으로 컴파일됨
    Evidence: .sisyphus/evidence/task-05-cacheconfig-compile.txt

  Scenario: CacheManager Bean 생성 검증
    Tool: Bash
    Steps:
      1. cd services/service-a/backend && ./gradlew bootRun &
      2. curl http://localhost:8080/actuator/beans | grep cacheManager
    Expected Result: cacheManager Bean이 정상적으로 생성됨
    Evidence: .sisyphus/evidence/task-05-cache-beans.json
  ```

- [ ] 6. application-docker.yml 설정 업데이트

  **What to do**:
  - Spring Cache 설정 추가 (type: caffeine,redis)
  - Redis 호스트를 Memorystore Private IP로 변경
  - Cache TTL 설정

  **Must NOT do**:
  - 기존 Redis 컨테이너 호스트 유지

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `git-master`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 5, 7)
  - **Blocks**: Task 8 (docker-compose)
  - **Blocked By**: Task 4 (의존성)

  **References**:
  - `services/service-a/backend/src/main/resources/application-docker.yml` - 현재 설정
  - Spring Boot Cache Docs: `https://docs.spring.io/spring-boot/docs/current/reference/html/features.html#features.caching`

  **Acceptance Criteria**:
  - [ ] spring.cache.type 설정 추가
  - [ ] spring.redis.host를 환경변수로 변경
  - [ ] Cache TTL 설정 추가

  **QA Scenarios**:
  ```
  Scenario: application-docker.yml 검증
    Tool: Bash
    Steps:
      1. grep "spring.cache" services/service-a/backend/src/main/resources/application-docker.yml
      2. Output에 "type" 및 "caffeine", "redis" 포함 확인
    Expected Result: Cache 설정이 정상적으로 추가됨
    Evidence: .sisyphus/evidence/task-06-app-yml-validation.txt
  ```

- [ ] 7. CacheWarmupRunner 구현

  **What to do**:
  - CommandLineRunner 구현
  - Dummy Data 500건 프리로드
  - Cache Warm-up 로깅

  **Must NOT do**:
  - 실제 DB 데이터 사용 (Dummy Data만)
  - 비즈니스 로직에 영향

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: `git-master`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 5, 6)
  - **Blocks**: Task 12 (Cache Hit Ratio 검증)
  - **Blocked By**: Task 5 (CacheConfig)

  **References**:
  - `services/service-a/backend/src/main/java/com/exit8/service/LoadScenarioService.java` - Dummy Data 생성 패턴
  - Spring Boot CommandLineRunner Docs

  **Acceptance Criteria**:
  - [ ] CacheWarmupRunner.java 파일 생성
  - [ ] @Component 어노테이션 추가
  - [ ] 500건 Dummy Data 캐시에 로드
  - [ ] Warm-up 완료 로그 출력

  **QA Scenarios**:
  ```
  Scenario: Cache Warm-up 실행 검증
    Tool: Bash
    Steps:
      1. docker logs service-a-backend 2>&1 | grep "Cache warm-up"
      2. Output에 "500" 포함 확인
      3. Output에 "completed" 포함 확인
    Expected Result: Cache Warm-up이 정상적으로 실행됨
    Evidence: .sisyphus/evidence/task-07-warmup-logs.txt
  ```

- [ ] 8. docker-compose.yml Redis 컨테이너 제거

  **What to do**:
  - Redis 서비스 제거
  - Redis 관련 볼륨 제거
  - 환경변수를 Memorystore 연결로 변경

  **Must NOT do**:
  - 다른 서비스 설정 변경
  - 네트워크 설정 변경

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `git-master`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 9, 10)
  - **Blocks**: Task 11 (연결 테스트)
  - **Blocked By**: Tasks 1-7

  **References**:
  - `docker-compose.yml` - 현재 Redis 서비스 설정 (lines 79-98)

  **Acceptance Criteria**:
  - [ ] Redis 서비스 제거
  - [ ] redis_data 볼륨 제거
  - [ ] REDIS_HOST 환경변수 추가

  **QA Scenarios**:
  ```
  Scenario: docker-compose 검증
    Tool: Bash
    Steps:
      1. docker compose config --quiet
      2. docker compose config | grep -c redis
      3. Output이 0인지 확인 (Redis 서비스 없음)
    Expected Result: docker-compose.yml에 Redis 서비스가 없음
    Evidence: .sisyphus/evidence/task-08-compose-validation.txt
  ```

- [ ] 9. .env.example Memorystore 환경변수 추가

  **What to do**:
  - REDIS_HOST 환경변수 추가
  - REDIS_PORT 환경변수 추가
  - 주석으로 Memorystore 사용 명시

  **Must NOT do**:
  - 실제 Private IP 노출 (changeme 사용)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `git-master`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 8, 10)
  - **Blocks**: None
  - **Blocked By**: Task 8

  **References**:
  - `.env.example` - 현재 환경변수 템플릿

  **Acceptance Criteria**:
  - [ ] REDIS_HOST 추가
  - [ ] REDIS_PORT 추가 (6379)
  - [ ] GCP Memorystore 사용 주석 추가

  **QA Scenarios**:
  ```
  Scenario: .env.example 검증
    Tool: Bash
    Steps:
      1. grep "REDIS_HOST" .env.example
      2. Output에 "Memorystore" 포함 확인
    Expected Result: Memorystore 환경변수가 추가됨
    Evidence: .sisyphus/evidence/task-09-env-example.txt
  ```

- [ ] 10. Grafana Cache Dashboard 생성

  **What to do**:
  - Cache Hit Ratio 패널 추가
  - Cache Miss Rate 패널 추가
  - TTL 분포 패널 추가

  **Must NOT do**:
  - 기존 대시보드 삭제

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: `frontend-ui-ux`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 8, 9)
  - **Blocks**: Task 12 (Cache Hit Ratio 검증)
  - **Blocked By**: Task 5 (Cache 메트릭 정의)

  **References**:
  - `services/grafana/dashboards/system-overview.json` - 기존 대시보드 구조
  - Prometheus Metrics: `cache_hits_total`, `cache_misses_total`

  **Acceptance Criteria**:
  - [ ] cache-performance.json 파일 생성
  - [ ] Cache Hit Ratio 패널 포함
  - [ ] Grafana provisioning 설정

  **QA Scenarios**:
  ```
  Scenario: Grafana Dashboard 검증
    Tool: Bash
    Steps:
      1. curl -s http://localhost:3001/api/search?query=cache | grep "cache-performance"
    Expected Result: Cache 대시보드가 Grafana에 로드됨
    Evidence: .sisyphus/evidence/task-10-grafana-dashboard.txt
  ```

- [ ] 11. Memorystore 연결 테스트

  **What to do**:
  - VM에서 Memorystore 연결 테스트
  - redis-cli ping 테스트
  - Spring Boot 애플리케이션 연결 테스트

  **Must NOT do**:
  - 외부 IP에서 테스트 (불가)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: `git-master`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 12, 13)
  - **Blocks**: Task 12, 13
  - **Blocked By**: Tasks 1-3, 8

  **References**:
  - Memorystore Connection: `https://cloud.google.com/memorystore/docs/redis/connect-redis-instance`

  **Acceptance Criteria**:
  - [ ] redis-cli ping → PONG
  - [ ] Spring Boot 로그에 "Connected to Redis" 확인
  - [ ] 애플리케이션 정상 시작

  **QA Scenarios**:
  ```
  Scenario: Memorystore 연결 테스트
    Tool: Bash
    Steps:
      1. gcloud compute ssh exit8-server --command="redis-cli -h MEMORSTORE_IP ping"
      2. Output이 "PONG"인지 확인
    Expected Result: Memorystore에 정상적으로 연결됨
    Evidence: .sisyphus/evidence/task-11-memorystore-connection.txt

  Scenario: Spring Boot Redis 연결 테스트
    Tool: Bash
    Steps:
      1. docker logs service-a-backend 2>&1 | grep -i "redis"
      2. Output에 "Connected" 또는 "lettuce" 포함 확인
    Expected Result: Spring Boot가 Redis에 정상적으로 연결됨
    Evidence: .sisyphus/evidence/task-11-spring-redis-connection.txt
  ```

- [ ] 12. Cache Hit Ratio 검증 (Prometheus)

  **What to do**:
  - Prometheus에서 cache_hits_total, cache_misses_total 메트릭 확인
  - Cache Hit Ratio 계산 (> 80% 목표)
  - Grafana 대시보드에서 시각화 확인

  **Must NOT do**:
  - 부하 테스트 없이 검증 (실제 트래픽 필요)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: `git-master`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 11, 13)
  - **Blocks**: Task 13
  - **Blocked By**: Tasks 7, 10, 11

  **References**:
  - Prometheus Query: `sum(cache_hits_total) / (sum(cache_hits_total) + sum(cache_misses_total))`

  **Acceptance Criteria**:
  - [ ] Prometheus에 cache_hits_total 메트릭 존재
  - [ ] Prometheus에 cache_misses_total 메트릭 존재
  - [ ] Cache Hit Ratio > 80%

  **QA Scenarios**:
  ```
  Scenario: Cache 메트릭 검증
    Tool: Bash
    Steps:
      1. curl -s http://localhost:9090/api/v1/query?query=cache_hits_total
      2. Output에 "data" 및 "result" 포함 확인
    Expected Result: Cache 메트릭이 Prometheus에 노출됨
    Evidence: .sisyphus/evidence/task-12-cache-metrics.txt

  Scenario: Cache Hit Ratio 검증
    Tool: Bash
    Steps:
      1. JMeter 부하 테스트 실행 (5분, 100 threads)
      2. curl -s 'http://localhost:9090/api/v1/query?query=sum(cache_hits_total)/(sum(cache_hits_total)+sum(cache_misses_total))'
      3. Output의 값이 0.8 이상인지 확인
    Expected Result: Cache Hit Ratio가 80% 이상
    Evidence: .sisyphus/evidence/task-12-hit-ratio.txt
  ```

- [ ] 13. JMeter 부하 테스트 + DB 부하 감소 확인

  **What to do**:
  - JMeter 부하 테스트 실행
  - DB 연결 수 모니터링 (hikaricp_connections_active)
  - Cache 미사용 시와 비교

  **Must NOT do**:
  - 운영 DB 사용 (테스트 DB만)

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: `git-master`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 11, 12)
  - **Blocks**: None
  - **Blocked By**: Tasks 11, 12

  **References**:
  - `services/service-a/jmeter/` - JMeter 테스트 스크립트
  - Prometheus Query: `hikaricp_connections_active`

  **Acceptance Criteria**:
  - [ ] JMeter 테스트 성공 (100 threads, 5분)
  - [ ] DB 연결 수 < 50% 감소 (Cache 사용 전 vs 후)
  - [ ] 응답 시간 < 100ms (P95)

  **QA Scenarios**:
  ```
  Scenario: JMeter 부하 테스트
    Tool: Bash
    Steps:
      1. jmeter -n -t services/service-a/jmeter/load-test.jmx -l results.jtl
      2. grep "success" results.jtl | wc -l
    Expected Result: JMeter 테스트가 성공적으로 완료됨
    Evidence: .sisyphus/evidence/task-13-jmeter-results.jtl

  Scenario: DB 부하 감소 확인
    Tool: Bash
    Steps:
      1. Cache OFF 상태에서 hikaricp_connections_active 측정
      2. Cache ON 상태에서 hikaricp_connections_active 측정
      3. 비교하여 50% 이상 감소 확인
    Expected Result: Cache 사용 시 DB 연결 수가 50% 이상 감소
    Evidence: .sisyphus/evidence/task-13-db-load-comparison.txt
  ```

---

## Final Verification Wave (MANDATORY)

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Verify all "Must Have" present, all "Must NOT Have" absent, evidence files exist.

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `./gradlew build`, check for `as any`, unused imports, console.log.

- [ ] F3. **Real Manual QA** — `unspecified-high`
  Execute all QA scenarios, capture evidence, test integration.

- [ ] F4. **Scope Fidelity Check** — `deep`
  Verify no scope creep, all tasks match spec, no unaccounted changes.

---

## Commit Strategy

- **Commit 1**: `infra/scripts/create-memorystore.sh`, `create-private-service-access.sh`
  - Message: `infra: add Memorystore for Redis setup scripts`
  - Pre-commit: `shellcheck scripts/*.sh`

- **Commit 2**: `build.gradle`, `CacheConfig.java`, `CacheWarmupRunner.java`, `application-docker.yml`
  - Message: `feat(service-a): implement 2-Tier Cache with Caffeine + Redis`
  - Pre-commit: `./gradlew test`

- **Commit 3**: `docker-compose.yml`, `.env.example`
  - Message: `infra: remove Redis container, add Memorystore config`
  - Pre-commit: `docker compose config --quiet`

- **Commit 4**: `services/grafana/dashboards/cache-performance.json`
  - Message: `feat(monitoring): add Grafana Cache performance dashboard`
  - Pre-commit: `jq . dashboard.json > /dev/null`

---

## Success Criteria

### Verification Commands
```bash
# Memorystore 연결 확인
gcloud redis instances describe exit8-redis --region=asia-northeast3 | grep state
# Expected: state: READY

# Cache Hit Ratio 확인
curl -s 'http://localhost:9090/api/v1/query?query=sum(cache_hits_total)/(sum(cache_hits_total)+sum(cache_misses_total))' | jq '.data.result[0].value[1]'
# Expected: > 0.8

# DB 연결 수 확인
curl -s 'http://localhost:9090/api/v1/query?query=hikaricp_connections_active{service="service-a"}' | jq '.data.result[0].value[1]'
# Expected: < 25 (Cache 사용 전 50의 50% 감소)
```

### Final Checklist
- [ ] Memorystore for Redis 연결 성공
- [ ] 2-Tier Cache 동작 확인 (Caffeine + Redis)
- [ ] Cache Hit Ratio > 80%
- [ ] DB 연결 수 < 50% 감소
- [ ] Grafana Cache 대시보드 정상
- [ ] JMeter 부하 테스트 성공
- [ ] All QA scenarios passed

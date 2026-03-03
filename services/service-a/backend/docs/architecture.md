# 시스템 아키텍처 및 설계 원칙
> 구조 + 설계 원칙 + 데이터 계층 정의

## 1. 아키텍처 개요

### 요청 처리 흐름
```
Client
  → TraceIdFilter
  → RateLimitFilter
  → Controller
  → Service (AOP Proxy: CircuitBreaker)   # + (Timer/Timed는 적용 방식 확인 필요)
  → Repository (JPA)
  → Observability (Metrics / Logs / EventBuffer / Snapshot APIs)
```

### 설계 의도
- 요청 식별(trace_id) → Filter 단계 차단 → 비즈니스 실행(Service) → Resilience 보호(CB) → 관측
- 보호(CircuitBreaker)와 관측(Observability)을 비즈니스 로직과 분리
- Service를 시스템 행위의 최소 단위로 정의

---

## 2. 전체 디렉토리 구조
```
services/service-a/backend/
├── build.gradle
├── .env
├── src/main/java/com/exit8/
│   ├── Application.java
│   │
│   ├── controller/        # API 진입점
│   │   ├── SystemHealthController.java
│   │   ├── LoadScenarioController.java
│   │   └── CircuitBreakerTestController.java
│   │
│   ├── service/           # 시스템 동작 로직 (부하 생성 · 차단 제어 · 상태 계산)
│   │   ├── SystemHealthService.java
│   │   ├── LoadScenarioService.java # 루프/실험 단위 제어
│   │   ├── DbUnitService.java # CB + Tx + 캐시 로직
│   │   └── CircuitBreakerTestService.java
│   │
│   ├── repository/        # 테스트용 데이터 접근
│   │   ├── LoadTestLogRepository.java
│   │   ├── DummyDataRepository.java
│   │   └── SystemLogRepository.java 
│   │
│   ├── domain/            # 부하/로그 도메인
│   │   ├── LoadTestLog.java
│   │   ├── DummyDataRecord.java
│   │   └── SystemLog.java
│   │
│   ├── dto/
│   │   ├── DefaultRequest.java
│   │   ├── DefaultResponse.java
│   │   ├── ErrorResponse.java
│   │   ├── SystemSnapshot.java
│   │   ├── ToggleResponse.java
│   │   └── SystemHealthStatus.java # redisCacheEnabled / hitRatio 추가
│   │
│   ├── exception/         # 공통 예외 처리
│   │   ├── ApiException.java
│   │   └── GlobalExceptionHandler.java
│   │
│   ├── filter/            # HTTP 진입 trace_id 생성
│   │   └── TraceIdFilter.java          # 요청 식별
│   │   ├── RateLimitFilter.java        # 차단 로직
│   │   └── ClientIpResolver.java       # IP 해석 책임 분리
│   │ 
│   ├── logging/           # AOP 기반 관측 로깅
│   │   ├── LogAspect.java                  # LOAD_START / END / FAIL 트리거
│   │   ├── LogLevelPolicy.java             # INFO / WARN / ERROR 판단
│   │   ├── LogEvent.java                   # 이벤트 도메인 (LOAD_START 등)
│   │   └── TraceContext.java               # MDC 기반 trace_id 접근 전용
│   │
│   ├── state/
│   │   └── RuntimeFeatureState.java        # 상태 저장소
│   │
│   ├── observability/     # 실시간 관측 이벤트 및 메모리 버퍼 (프론트 대시보드용)
│   │   ├── RequestEvent.java
│   │   ├── RequestEventBuffer.java
│   │   └── CacheMetrics.java               # hit/miss counter
│   │
│   └── config/
│       ├── datasource/                     # DB 설정
│       │   └── PostgresConfig.java
│       ├── redis/                          # redis 설정
│       │   └── RedisConfig.java
│       ├── observability/                  # Metrics / tracing 설정
│       │   └── MetricsConfig.java 
│       ├── constants/
│       │   └── CircuitNames.java
│       └── filter/                         # Filter 설정
│           └── FilterOrderConfig.java      # 순서 제어
│
└── src/main/resources/
    ├── application.yml
    ├── application-local.yml
    ├── application-docker.yml
    └── logback-spring.xml                   # JSON 구조 로그 출력

```

## 3. 계층별 책임 정의

### Filter Layer
| 구성               | 책임                         |
| ---------------- | -------------------------- |
| TraceIdFilter    | 요청 단위 trace_id 생성 및 MDC 저장 |
| RateLimitFilter  | IP 기반 1차 차단                |
| ClientIpResolver | X-Forwarded-For 파싱 책임 분리   |

- Service 진입 전 차단
- 차단 요청도 trace_id 포함
- Filter는 비즈니스 로직 없음

### Controller Layer
- 원칙
  1. 요청 바인딩만 수행
  2. Service 호출만 수행
  3. 검증·상태 판단·로깅 없음
```
Controller = API Adapter
```

### Service Layer
- 핵심 설계 원칙
  1. 모든 검증·제어는 Service 담당
  2. AOP 로깅 기준점 = Service 메서드
  3. checked exception 외부 전파 금지
  4. 관측 데이터 접근(RequestEventBuffer 등)도 반드시 Service를 통해 수행

- Service는 시스템 동작의 최소 단위다.
- 단, 부하 실험 구조에서는
  - LoadScenarioService는 “실험 제어 단위(loop driver)”
  - DbUnitService는 “CircuitBreaker 집계 단위(unit call)”
   로 역할을 분리한다.

### Resilience Layer
- Resilience4j CircuitBreaker
- Service 메서드를 AOP Proxy로 감싸는 방식으로 적용
- 보호 범위는 Service 호출 전체이며, 그 내부에서 **Cache/Repository 호출(DB 접근 포함)**이 수행된다.
- OPEN 상태에서는 Service 호출 자체가 차단되며 CallNotPermittedException 발생
- `GlobalExceptionHandler`에서 503 변환
- 보호 로직은 비즈니스 로직과 분리된다.

### Observability Layer
```
[Metrics]
  - Micrometer Counter / Timer
  - CacheMetrics (hit/miss)

[Event Buffer]
  - RequestEventBuffer (in-memory ring buffer)

[API]
  - SystemSnapshot
  - RecentRequests
```
- 관측 지점
  1. RateLimit 차단 시점
  2. CircuitBreaker OPEN 시점
  3. Service 실행 시작/종료 시점

---

## 4. 데이터 계층 설계

### PostgreSQL

- 테스트 도메인과 분리
- JPA 사용
- ddl-auto: update (테스트 단계)

| 테이블                       | 목적           |
| ------------------------- | ------------ |
| spring_load_test_logs     | 부하 실행 기록     |
| spring_dummy_data_records | DB 부하용       |
| spring_logs               | 시스템 로그 (미완성) |

### Redis
- Read-Through Cache 기반 부하 분산 테스트
- `/db-read` 전용
- TTL 기반 자연 만료 전략 사용
  - Docker 환경: redis-cache.ttl-seconds: 300 (5분)
  - GCP 환경: Spring cache/redis TTL 또는 별도 설정에 따라 600s(예: spring.cache.redis.time-to-live: 600s)

#### Key 네이밍 규칙
```
{prefix}:{service}:{app}:{resource}:{id}

# 예시
test:service-a-backend:spring:dummy-data-page:{pageIndex}-{size}
```
- 모든 Key는 TTL 필수
- 테스트용 Key는 test: prefix 사용
- Redis 장애는 try-catch로 DB fallback 처리
- Redis 지연으로 인한 메서드 실행 시간 증가 시 slow-call로 집계 (CB 기준)

---

## 5. RuntimeFeatureState

### 런타임 토글 상태 저장소
- RateLimit ON/OFF
- Redis Cache ON/OFF
- Snapshot 반영
- 프로세스 메모리 기반 상태
- 서버 재시작 시 application.yml 기준으로 초기화

---

## 6. UI ↔ API ↔ Service 정합성
- UI 버튼 · API 엔드포인트 · Service 메서드가 1:1로 매핑

| 기능(개념)           | API                              | Service                                     |
| --------------- | -------------------------------- | ------------------------------------------- |
| CPU 부하 시작       | `/api/load/cpu`                  | `LoadScenarioService.generateCpuLoad()`     |
| DB READ 부하 시작   | `/api/load/db-read`              | `simulateDbReadLoad()`                      |
| DB WRITE 부하 시작  | `/api/load/db-write`             | `simulateDbWriteLoad()`                     |
| Redis Warm-up | `/api/load/redis/warmup`         | `simulateDbReadLoad(500)`                   |
| 상태 표시           | `/api/system/health`             | `SystemHealthService.getCurrentStatus()`    |
| Snapshot 표시     | `/api/system/snapshot`           | `SystemHealthService.getSnapshot()`         |
| 최근 요청 피드        | `/api/system/recent-requests`    | `SystemHealthService.getRecentRequests()`   |
| RateLimit ON/OFF | `/api/system/rate-limit/toggle`  | `SystemHealthService.toggleRateLimit()`     |
| Redis ON/OFF    | `/api/system/redis-cache/toggle` | `SystemHealthService.toggleRedisCache()`    |
| 차단 테스트          | `/api/circuit/test`              | `CircuitBreakerTestService.callWithDelay()` |

### 규칙 강제 이유
1. 관측 가능성(Observability)
    - 로그, 메트릭, 이벤트가 Service 단위로 정확히 분리됨
    - AOP 로깅과 완벽하게 정렬됨
    - 요청 흐름 추적이 명확해짐
2. 부하 시나리오 단순화
    - “어떤 버튼이 어떤 부하를 만들었는지” 즉시 추적 가능
    - 테스트 결과 재현성 확보
3. UI ↔ 백엔드 커뮤니케이션 명확화
    - API 계약이 Service 단위로 고정됨
    - 프론트/백엔드/인프라 간 오해 제거
4. AOP 로깅 구조와 완벽하게 호환
    - Service.*(..) 기준으로 로깅 (실행 시간 측정, 성공/실패 판단, 이벤트 타입 분류)
    - Filter / Infra 레이어는 별도 관측 지점으로 분리됨

---

## 7. 관측 아키텍처

### Observability 구조
```
[Filter Layer]
  ├─ TraceIdFilter
  ├─ RateLimitFilter  ← 이벤트 발생 지점 1 (429)

[Controller Layer]
  └─ API Adapter

[Service Layer]  ← CircuitBreaker(AOP)가 Service 호출 전체를 보호
  ├─ LoadScenarioService (실험 제어)
  ├─ DbUnitService (CB 집계 단위 / read-through cache 포함)
  │    ├─ L1 Cache (Caffeine)
  │    ├─ L2 Cache (Redis, enabled/disabled 토글)
  │    └─ DB (Repository/JPA)
  ├─ SystemHealthService
  └─ CircuitBreakerTestService

[Resilience Layer]
  └─ Resilience4j CircuitBreaker (AOP Proxy) ← 이벤트 발생 지점 2 (OPEN → CallNotPermitted)

[Exception Layer]
  └─ GlobalExceptionHandler (CallNotPermittedException → 503)
 
[Observability Layer]
  ├─ Micrometer Counter / Timer
  ├─ CacheMetrics (hit/miss/error)
  └─ RequestEventBuffer (in-memory ring buffer)

[API Layer]
  ├─ SystemSnapshot API
  └─ RecentRequests API
```

### RateLimit
- IP 기반 1차 방어 레이어
- 반복적 부하를 차단하고 차단 이벤트 기록
- application.yml 설정 기반으로 초기 상태 결정
  - 서버 재시작 시에는 application.yml 설정 값으로 초기화
- 런타임 toggle API를 통해 변경 가능

### CircuitBreaker
- 2차 방어 레이어
- 내부 임계치 초과 시 OPEN 상태로 전환하여 시스템 보호
- OPEN 상태에서는 CallNotPermittedException이 즉시 발생
  - 해당 예외는 GlobalExceptionHandler에서 503으로 변환

### Prometheus 메트릭 노출
- Actuator + Micrometer 기반 메트릭 수집
- Grafana에서 시계열 분석 수행

### SystemSnapshot API
- 프론트엔드 상단 상태 표시를 위한 단일 데이터 소스
- Circuit 상태, DB Pool 상태, 평균 응답 시간 등

### Recent Requests API
- IP별 요청 이벤트를 구조화하여 제공
- 200 / 429 / 503 상태 기반 이벤트 피드

### 아키텍처 레벨
``` 
Client
  ↓
TraceIdFilter
  ↓
RateLimitFilter
  ↓
Controller
  ↓
Service  (CircuitBreaker가 Service 호출 전체를 보호)
     ├─ L1 Cache (Caffeine)
     ├─ L2 Cache (Redis)  # runtime toggle 가능
     └─ DB (JPA Repository)
     ↓
Repository
  ↓
Observability (Metrics / Logs / Snapshot)
```
- RateLimit: 트래픽 양을 제어하는 변수
- Redis: DB 부하 밀도를 제어하는 변수

---

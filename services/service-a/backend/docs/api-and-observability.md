# API 및 관측 계약
> API + 메트릭 + 보안(Vault) + 테스트 관련 정의 


## 1. 공통 응답 포맷
```
{
  "httpCode": 200,
  "data": {},
  "error": null
}

```
- httpCode : 실제 HTTP 상태 코드와 동일
- data : 성공 시 결과 데이터 (없으면 null 또는 {})
- error : 성공 시 항상 null

<br>

에러 시:
```
{
  "httpCode": 500,
  "data": null,
  "error": {
    "code": "INVALID_PARAM",
    "message": "durationMs max is 10000"
  }
}
```
- data : 에러 시 항상 null
- error.code : 비즈니스 에러 코드 (고정 문자열)
- error.message : 클라이언트 전달용 메시지

| 상황                   | 분류             |
| -------------------- | -------------- |
| Circuit OPEN         | 503            |
| DB 병목              | 200 + DEGRADED |
| 잘못된 파라미터         | 400            |

---

## 2. API 분류

### Load & Experiment APIs
- 시스템에 의도적 부하를 가하는 API
- 모든 호출은 상태 변화를 유발함
- side-effect 존재 
  - CPU 사용률 변화
  - DB Connection Pool 점유
  - CircuitBreaker 상태 변화
  - Metric 증가
  - 로그 이벤트 발생

> 테스트 목적의 API이며 운영 read-only API와 명확히 구분한다.

### Health & Observability APIs
- 시스템 현재 상태 조회 API
- UI / Prometheus / 운영 모니터링 연계
- 기본적으로 read-only
- 비즈니스 상태를 변경하지 않음
- 단, 예외적으로:
  - `/api/system/rate-limit/toggle`,  `/api/system/redis-cache/toggle` API는 테스트 제어용 관리며 상태를 변경한다.
  - 운영 Health API와는 성격이 다름

---

## 3. 부하 테스트 관련 API

### 시스템 상태 조회 (SystemHealth)
`GET /api/system/health`

- UI 빠른 상태 확인용
- 응답 상태 판단 기준
```
UP
- CircuitBreaker 상태: CLOSED
- Hikari Pool waitingThreads == 0

DEGRADED
- CircuitBreaker 상태: HALF_OPEN
- Hikari Pool waitingThreads > 0
- idle == 0 && waiting > 0 (풀 고갈 조짐)

DOWN
- CircuitBreaker 상태: OPEN
- 핵심 기능 차단 상태
```

<br>

### CPU 부하 생성
`POST /api/load/cpu`

- CPU saturation 상황 재현
- GC / 응답 지연 / CircuitBreaker 영향 관측
- sleep ❌ (스레드 블로킹만 발생)
- busy-loop 연산으로 실제 CPU 점유
- `durationMs <= 10000` 초과 시 ApiException

### DB READ 부하 생성
`POST /api/load/db-read`

- DB 커넥션 풀 고갈
- SELECT 병목 상황 관측
- DummyData 반복 SELECT
- 캐시 적용 여부는 feature.redis-cache.enabled 토글로 제어
- **repeatCount 만큼 findById / findAll 반복**

### DB WRITE 부하 생성
`POST /api/load/db-write`

- WAL 증가
- 트랜잭션 누적 상황 재현
- DummyData INSERT 반복
- flush 전략은 기본값 유지 (추후 변경 가능)

<br>

### CircuitBreaker 상태 전이 테스트
`POST /api/circuit/test`

#### 동작 흐름
1. 내부 timeout 발생
2. 실패 누적
3. CircuitBreaker OPEN 전환
4. CallNotPermittedException 발생
5. 503 반환

---

## 4. 로깅/관측 계약
### 원칙
- trace_id 기반 요청 추적
- 비즈니스 로직 로그는 Service / Controller에 두지 않음
- 흐름 로깅은 AOP로 일원화
- 인프라 이벤트(CircuitBreaker 등)는 예외적으로 Service에서 기록

<br>

### MDC + AOP를 사용하는 이유
- 로그를 요청 단위(trace_id) 로 자동 묶기 위함     
   → 각 로그 호출마다 trace_id를 전달하지 않아도 됨
- 비즈니스 로직(Service)과 로깅 관심사를 분리하기 위함
   → 로깅 코드가 서비스 로직을 오염시키지 않음
- 실행 시간, 성공/실패, 이벤트 타입을
   모든 Service 메서드에 동일한 기준으로 적용하기 위함
- 로그 포맷·레벨·필드를 중앙에서 통제하여
   운영 환경에서도 일관된 분석이 가능하도록 하기 위함

#### LogAspect
- Service 메서드 단위 실행 흐름 로깅
- LOAD_START → LOAD_END / LOAD_FAIL / LOAD_ERROR
- 실행 시간(duration) 측정
- 모든 로그는 trace_id 기준으로 연결

#### TraceContext
- MDC 기반 trace_id 조회 전용
- Service / AOP / Exception에서 공통 사용
- trace_id 생성 책임 없음

#### LogLevelPolicy
- Circuit OPEN → WARN
- DB / I/O → ERROR
- 추후 CRITICAL 확장 가능

#### TraceIdFilter (요청 단위 추적의 시작점)
- HTTP 요청 진입 시 trace_id 생성
- 외부 요청에 X-Trace-Id 헤더가 존재할 경우 재사용
- MDC에 trace_id 저장하여 전 구간 자동 전파
- 요청 종료 시 MDC clear로 쓰레드 오염 방지

#### LogEvent (이벤트 표준화)
- 로그 메시지에 포함될 이벤트 타입 상수 정의
- 이벤트 기준으로 로그 집계 및 분석 가능

  | Event               | 의미                  |
  | ------------------- |---------------------|
  | LOAD_START          | Service 실행 시작       |
  | LOAD_END            | 정상 종료               |
  | LOAD_FAIL           | 비치명적 실패             |
  | LOAD_ERROR          | 치명적 실패              |
  | CIRCUIT_OPEN        | CircuitBreaker OPEN |
  | UNHANDLED_EXCEPTION | AOP 밖 예외            |
  | RATE_LIMITED        | RateLimit에 의해 요청 차단 |
  | BUSINESS_EXCEPTION  | ApiException 발생 (비즈니스 예외) |

<br>

#### GlobalExceptionHandler (최종 방어 로깅)
- AOP 범위를 벗어난 예외에 대해 반드시 로그 기록
- trace_id 기준으로 “로그 없는 장애” 방지
- 비즈니스 예외와 시스템 예외 로그 레벨 분리

<br>

#### RateLimitFilter
- TraceIdFilter 이후 실행
- 차단 요청도 trace_id 포함
- Service/AOP로 진입하지 않음
- 관측 이벤트 및 메트릭은 기록됨

```
Request
  → TraceIdFilter
      → trace_id 생성
  → RateLimitFilter
      → 차단/허용 판단
  → Controller
    → Service
```

### trace_id 전파 검증 (요청 단위 추적 불변식 확인)

- 로그 확인 (trace_id 기준으로 START/END 로그가 모두 존재해야 함)
```
docker exec -it service-a-backend sh -c "grep test-trace-123 /app/logs/app.log"
```

<br>

#### 외부 trace_id가 전달된 요청
1. 시나리오
  - 클라이언트 요청에 X-Trace-Id 헤더가 포함된 경우
  - Filter는 새 trace_id를 생성하지 않고, 전달된 값을 그대로 사용한다.

2. 기대 동작
   - 요청 1건에 대해 동일한 trace_id를 가진 로그가
     - Service 실행 시작 시 1건 (LOAD_START)
     - Service 실행 종료 시 1건 (LOAD_END)
     - 반드시 한 쌍으로 기록되어야 한다.
   - START/END 로그 사이에서 trace_id는 절대 변경되면 안 된다.

3. 요청 1회 호출
```
curl -X POST "http://localhost:8080/api/load/cpu?durationMs=1000" -H "X-Trace-Id: test-trace-123"
```

> ✔ 외부에서 전달된 trace_id(test-trace-123)가 Filter → MDC → AOP → 로그까지 변경 없이 유지됨을 검증한다.

<br>

#### trace_id가 없는 요청
1. 시나리오
  - 클라이언트 요청에 X-Trace-Id 헤더가 없는 경우
  - Filter는 새로운 trace_id를 생성한다.

2. 기대 동작
  - Filter에서 생성된 trace_id가 요청 전 구간에 전파된다.
  - LOAD_START / LOAD_END 로그에 동일한 신규 trace_id가 기록되어야 한다.
  - START와 END 사이에서 trace_id가 달라지면 안 된다.

> ✔ trace_id 미존재 요청에서도 요청 단위 추적이 반드시 보장됨을 검증한다.

---

## 5. Vault 연동
- DB 자격 증명을 애플리케이션 외부로 분리하기 위해 Spring Cloud Vault 사용
- Vault 기반 설정 로딩 구조를 검증

### Spring Cloud Vault Client 연동
- 애플리케이션 기동 시 Vault에서 설정 값을 로드
- Vault KV(v2)를 Spring PropertySource로 통합

### DB 자격 증명 완전 외부화
- spring.datasource.username / password 하드코딩 제거
- Vault에 저장된 db.username, db.password를 명시적으로 매핑

#### 검증 항목
- Spring Cloud Vault Client 기동 시 Vault 연결 
- DB 자격 증명 로딩 성공 / 실패 시 기동 결과

### 의도적으로 제외한 범위
- Secret rotation 
- Vault Auth (AppRole, Kubernetes 등)
- Vault HA / TLS 구성

---


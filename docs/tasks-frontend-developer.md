# Frontend 추가 작업 목록

> Service-A 프론트엔드 대시보드 + Grafana 부하 테스트 대시보드.
> Backend에서 제공하는 API와 Prometheus 메트릭을 시각화한다.

---

## Part 1: Service-A Frontend — 실험 관측 대시보드

### 역할 분담 원칙
```
Grafana  = 숫자 메트릭 시계열 (CPU, 메모리, DB 커넥션 추이 그래프)
Frontend = 이벤트 기반 실시간 관측 (IP별 차단/통과, 보안 이벤트 피드)
```

---

### 1-1. 시스템 상태 표시 (상단 고정)

**데이터 소스**: `GET /api/system/snapshot` (1~2초 폴링)

```
┌────────────────────────────────────────────────┐
│  Circuit Breaker    Rate Limit    DB Pool       │
│  🟢 CLOSED          ⚫ OFF        35/50         │
│                                   (70% 사용)    │
└────────────────────────────────────────────────┘
```

| 항목 | 필드 | 표시 |
|------|------|------|
| Circuit Breaker | `circuitBreakerState` | 🟢CLOSED / 🟡HALF_OPEN / 🔴OPEN |
| Rate Limit | 토글 API 응답 or 상태 | ⚫OFF / 🟢ON |
| DB Pool | `activeConnections` / `totalConnections` | 게이지 또는 숫자 |
| 대기 스레드 | `waitingThreads` | 0이면 숨김, >0이면 ⚠️ 표시 |
| 평균 응답 | `avgResponseTimeMs` | ms 단위 |

---

### 1-2. 실시간 요청 피드 (메인 영역)

**데이터 소스**: `GET /api/system/recent-requests?limit=50` (1~2초 폴링)

```
┌──────────┬────────────┬─────────────┬──────┬───────────┐
│ 시간      │ IP          │ 경로         │ 상태  │ 이벤트     │
├──────────┼────────────┼─────────────┼──────┼───────────┤
│ 09:01:00 │ 10.10.10.10│ /db-read     │ 200  │           │
│ 09:01:01 │ 10.10.10.10│ /db-read     │ 200  │           │
│ 09:01:02 │ 20.20.20.20│ /db-read     │ 200  │           │
│ 09:01:03 │ 10.10.10.10│ /db-read     │ 429  │ RATE_LIMITED│ ← 빨간색 하이라이트
│ 09:01:03 │ 10.10.10.10│ /db-read     │ 503  │ CIRCUIT_OPEN│ ← 빨간색
│ 09:01:04 │ 20.20.20.20│ /db-read     │ 200  │           │ ← 정상 (초록색)
└──────────┴────────────┴─────────────┴──────┴───────────┘
```

**UI 포인트:**
- status 200 → 기본색 (또는 초록)
- status 429 → 빨간 배경 (Rate Limit 차단)
- status 503 → 주황 배경 (Circuit Open)
- status 500 → 빨간 텍스트 (서버 에러)
- IP별 색상 구분 → Attack IP(10.10.10.10)와 Normal IP(20.20.20.20) 시각적 분리
- 새 행이 추가되면 위에서 아래로 스크롤 (최신이 위)

---

### 1-3. IP별 통계 요약 (사이드바 또는 하단)

recent-requests 데이터를 프론트에서 집계:

```
┌─────────────────────────────┐
│  IP별 요약                   │
│                             │
│  📍 10.10.10.10 (Attack)     │
│     총 요청: 1,247            │
│     성공(200): 800 (64%)     │
│     차단(429): 423 (34%)     │
│     에러(5xx): 24 (2%)       │
│                             │
│  📍 20.20.20.20 (Normal)     │
│     총 요청: 150              │
│     성공(200): 148 (99%)     │
│     차단(429): 0 (0%)        │ ← Rate Limit이 정상 IP를 보호
│     에러(5xx): 2 (1%)        │
└─────────────────────────────┘
```

이 비교가 Rate Limit 실험의 핵심 시연 포인트.
"공격 IP는 차단되고, 정상 IP는 보호된다."

---

### 1-4. Rate Limit 토글 버튼 (선택)

Backend에서 `POST /api/system/rate-limit/toggle` 구현 시:

```
[ Rate Limit: OFF 🔴 ]  ← 클릭하면 ON으로 전환
[ Rate Limit: ON  🟢 ]  ← 클릭하면 OFF로 전환
```

시연 흐름:
1. Rate Limit OFF 상태로 JMeter 실행 → 정상 IP도 피해
2. 토글 ON → 공격 IP만 차단, 정상 IP 보호 확인

---

## Part 2: Grafana 대시보드 — 부하 테스트 전용

### 현재 상태
- `system-overview.json`: CPU 게이지, Memory 게이지, Service Health (up/down) 3개 패널만 존재
- JMeter 실험에 필요한 메트릭 패널 없음

### 새 대시보드: `jmeter-experiment.json`

부하 테스트 실험 관측 전용 대시보드. 아래 패널을 추가한다.

---

### 2-1. HikariCP Connection Pool (Time Series)

JMeter 부하의 핵심 관측 대상. pool-size 50 대비 사용량 추이.

```
Query: hikaricp_connections_active{application="service-a-backend"}
Query: hikaricp_connections_idle{application="service-a-backend"}
Query: hikaricp_connections_pending{application="service-a-backend"}

임계선: y=50 (max pool size)
```

| 메트릭 | 설명 | 알람 기준 |
|--------|------|----------|
| `hikaricp_connections_active` | 현재 사용 중인 커넥션 | >45 경고 |
| `hikaricp_connections_idle` | 유휴 커넥션 | =0 경고 |
| `hikaricp_connections_pending` | 대기 중인 스레드 | >0 경고 |
| `hikaricp_connections_timeout_total` | 타임아웃 누적 | >0 위험 |

---

### 2-2. Circuit Breaker 상태 (State Timeline)

```
Query: resilience4j_circuitbreaker_state{name="testCircuit"}
    value 0=CLOSED, 1=OPEN, 2=HALF_OPEN

시각화 타입: State Timeline (Grafana 내장)
    CLOSED → 초록
    OPEN → 빨강
    HALF_OPEN → 노랑
```

---

### 2-3. HTTP 응답 코드 분포 (Stacked Bar / Pie)

```
Query: sum by(status) (increase(http_server_requests_seconds_count{application="service-a-backend"}[1m]))

범례:
    200 → 초록
    429 → 빨강 (Rate Limit)
    500 → 주황
    503 → 보라 (Circuit Open)
```

---

### 2-4. Rate Limit 차단 추이 (Time Series)

Backend에서 커스텀 메트릭 추가 후:

```
Query: rate(rate_limit_blocked_total[1m])
Query: rate(rate_limit_allowed_total[1m])
```

---

### 2-5. 응답 시간 추이 (Time Series)

```
Query: rate(http_server_requests_seconds_sum{application="service-a-backend", uri="/api/load/db-read"}[1m])
       /
       rate(http_server_requests_seconds_count{application="service-a-backend", uri="/api/load/db-read"}[1m])

단위: seconds → milliseconds 변환 (* 1000)
```

---

### 2-6. JVM 메모리 (Gauge)

부하 중 JVM 메모리 압박 관측:

```
Query: jvm_memory_used_bytes{application="service-a-backend", area="heap"}
Query: jvm_memory_max_bytes{application="service-a-backend", area="heap"}
```

---

### 대시보드 레이아웃 권장

```
Row 1: [CB State Timeline (w=12)] [HTTP Status 분포 (w=12)]
Row 2: [HikariCP Pool (w=16)]     [Rate Limit 차단 (w=8)]
Row 3: [응답 시간 추이 (w=16)]     [JVM Heap (w=8)]
```

---

## Part 3: 기존 Grafana 수정

### prometheus.yml 서비스명 오류 수정

현재 Prometheus가 메트릭 수집에 실패할 수 있는 설정 오류:

```yaml
# 현재 (Docker 서비스명과 불일치)
- job_name: 'service-a'
  targets: ['service-a:8080']       # ← 존재하지 않는 DNS

- job_name: 'service-b'
  targets: ['service-b:8000']       # ← 존재하지 않는 DNS

# 수정 (docker-compose.yml 서비스 키와 일치)
- job_name: 'service-a'
  targets: ['service-a-backend:8080']

- job_name: 'service-b'
  targets: ['service-b-backend:8000']
```

docker-compose.yml의 서비스 키가 `service-a-backend`, `service-b-backend`이므로
Docker 내부 DNS도 이 이름으로 해석된다. 현재 설정으로는 scrape 실패 상태일 수 있음.

### system-overview.json 개선

현재 3개 패널(CPU, Memory, Up/Down)만 있음. 아래 추가 권장:

| 추가 패널 | 쿼리 |
|----------|------|
| Disk Usage | `node_filesystem_avail_bytes` |
| Network I/O | `rate(node_network_receive_bytes_total[5m])` |
| PostgreSQL Active Connections | `pg_stat_activity_count` |
| Redis Memory | `redis_memory_used_bytes` |

---

## 작업 순서 권장

```
1. prometheus.yml 서비스명 수정 (Grafana 데이터 수집 전제조건)
2. Grafana jmeter-experiment 대시보드 생성 (기존 Prometheus 메트릭 활용)
3. Service-A Frontend 상태 표시 + 요청 피드 구현 (Backend API 완성 후)
4. system-overview.json 패널 추가
```

> Frontend 대시보드(3번)는 Backend의 snapshot/recent-requests API 완성 후 작업 가능.
> Grafana 대시보드(2번)는 Prometheus 기본 메트릭으로 먼저 구성 가능 (커스텀 메트릭은 나중에 추가).

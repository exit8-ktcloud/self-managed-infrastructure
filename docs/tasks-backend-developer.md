# Service-A Backend 추가 작업 목록

> 부하 테스트(JMeter) 시나리오의 관측 가능성과 방어 기제를 완성하기 위한 작업.
> 프론트엔드 대시보드 및 Grafana에서 데이터를 소비할 수 있도록 API와 메트릭을 제공한다.

---

## 1. RateLimitFilter 구현 (X-Forwarded-For IP 파싱 포함)

### 위치
`com.exit8.filter.RateLimitFilter.java`

### 요구사항

```java
// IP 추출 로직 (핵심)
// 프록시 체인: X-Forwarded-For: <원본 IP>, <프록시1 IP>, <프록시2 IP>
// 항상 첫 번째 IP를 사용
String xff = request.getHeader("X-Forwarded-For");
String clientIp = (xff != null) ? xff.split(",")[0].trim() : request.getRemoteAddr();
```

- `application.yml`의 `rate-limit.enabled` 값에 따라 ON/OFF
- IP 기반 Bucket4j 토큰 버킷 (이미 설계됨)
- 차단 시 HTTP 429 응답 + 로그:
  ```
  log.warn("event=RATE_LIMITED ip={} trace_id={}", clientIp, MDC.get("trace_id"));
  ```
- Prometheus 카운터 노출 (2번 항목 참고)

### JMeter 연동 검증
| 요청 경로 | X-Forwarded-For | 추출 IP |
|-----------|----------------|---------|
| JMeter → Backend 직접 | `10.10.10.10` | `10.10.10.10` |
| NPM → nginx → Backend | `10.10.10.10, 172.18.0.5` | `10.10.10.10` |
| 브라우저 (프록시 없음) | (없음) | `request.getRemoteAddr()` |

### 참고
- `TraceIdFilter`는 이미 `OncePerRequestFilter` 기반으로 존재 → 동일 패턴 사용
- 필터 순서: `TraceIdFilter` → `RateLimitFilter` → Controller
  - trace_id가 먼저 설정되어야 Rate Limit 로그에 포함 가능

---

## 2. Prometheus 커스텀 메트릭 추가

### 위치
RateLimitFilter, CircuitBreakerTestService, 또는 별도 MetricsService

### 추가할 메트릭

```
# Rate Limit
rate_limit_blocked_total{ip="10.10.10.10"}          # 차단 횟수 (Counter)
rate_limit_allowed_total                              # 통과 횟수 (Counter)

# 요청 IP별 분류
http_requests_by_ip_total{ip="10.10.10.10", status="200"}   # IP별 요청 수 (Counter)
http_requests_by_ip_total{ip="10.10.10.10", status="429"}   # IP별 차단 수

# DB Pool (Hikari 기본 메트릭은 이미 actuator에 있지만, 명시적 태깅)
# hikaricp_connections_active, hikaricp_connections_idle 등은 이미 노출됨
# → 추가 불필요, Grafana에서 직접 쿼리
```

### 구현 예시
```java
@RequiredArgsConstructor
public class RateLimitFilter extends OncePerRequestFilter {
    private final MeterRegistry meterRegistry;

    // 차단 시
    meterRegistry.counter("rate_limit_blocked_total", "ip", clientIp).increment();

    // 통과 시
    meterRegistry.counter("rate_limit_allowed_total").increment();
}
```

---

## 3. SystemSnapshot API 엔드포인트

### 위치
`com.exit8.controller.SystemHealthController.java` 에 추가 또는 새 컨트롤러

### 엔드포인트
```
GET /api/system/snapshot
```

### 응답 (SystemSnapshot DTO 활용)
```json
{
  "success": 200,
  "data": {
    "timestamp": "2026-02-13T09:01:00.000+09:00",
    "circuitBreakerState": "CLOSED",
    "activeConnections": 35,
    "idleConnections": 15,
    "totalConnections": 50,
    "waitingThreads": 0,
    "hikariTimeoutCount": 0.0,
    "avgResponseTimeMs": 45
  }
}
```

### 구현 참고
- `SystemHealthService.getCurrentStatus()`에 이미 HikariPoolMXBean 접근 로직 있음
- `avgResponseTimeMs`가 현재 `120`으로 하드코딩됨 → Micrometer에서 실제 값 계산:
  ```java
  // application.yml에 이미 prometheus 메트릭 노출 설정 있음
  // http_server_requests_seconds_sum / http_server_requests_seconds_count 로 계산 가능
  Timer timer = meterRegistry.find("http.server.requests").timer();
  long avgMs = (timer != null) ? (long)(timer.mean(TimeUnit.MILLISECONDS)) : 0;
  ```
- `hikariTimeoutCount`는 `hikaricp_connections_timeout_total` 메트릭에서 추출
- 프론트엔드에서 1~2초 간격 폴링 예정 → 성능 부담 최소화 필요 (캐싱 고려)

---

## 4. 요청 이벤트 로그 API (프론트엔드 실시간 피드용)

### 엔드포인트
```
GET /api/system/recent-requests?limit=50
```

### 응답
```json
{
  "success": 200,
  "data": [
    {
      "timestamp": "2026-02-13T09:01:00.123+09:00",
      "ip": "10.10.10.10",
      "method": "POST",
      "path": "/api/load/db-read",
      "status": 429,
      "event": "RATE_LIMITED",
      "durationMs": 2
    },
    {
      "timestamp": "2026-02-13T09:01:00.456+09:00",
      "ip": "20.20.20.20",
      "method": "POST",
      "path": "/api/load/db-read",
      "status": 200,
      "event": "REQUEST_COMPLETED",
      "durationMs": 45
    }
  ]
}
```

### 구현 방식
- 인메모리 Ring Buffer (최근 N건만 보관, 예: 200건)
- 필터에서 요청 완료 시 버퍼에 기록
- 별도 DB 저장 불필요 (실험 관측 목적)
- 메모리 사용량: 200건 × ~200bytes ≈ 40KB (무시 가능)

```java
// 예시 구조
@Component
public class RequestEventBuffer {
    private final ConcurrentLinkedDeque<RequestEvent> buffer = new ConcurrentLinkedDeque<>();
    private static final int MAX_SIZE = 200;

    public void add(RequestEvent event) {
        buffer.addFirst(event);
        while (buffer.size() > MAX_SIZE) buffer.removeLast();
    }

    public List<RequestEvent> getRecent(int limit) {
        return buffer.stream().limit(limit).toList();
    }
}
```

---

## 5. Rate Limit ON/OFF 토글 API (선택)

### 엔드포인트
```
POST /api/system/rate-limit/toggle
```

### 용도
- 시연 중 Rate Limit ON/OFF 전환하여 효과 비교
- 현재 `application.yml`의 `rate-limit.enabled: false`를 런타임에서 변경

### 응답
```json
{
  "success": 200,
  "data": { "rateLimitEnabled": true }
}
```

---

## 작업 순서 권장

```
1. RateLimitFilter + IP 파싱 (핵심 방어 기제)
2. Prometheus 커스텀 메트릭 (Grafana 연동)
3. SystemSnapshot API (프론트엔드 대시보드 데이터)
4. RequestEventBuffer + recent-requests API (프론트엔드 실시간 피드)
5. Rate Limit 토글 API (시연 편의)
```

# EXIT8 – Backend Spring (Load & Observability Playground)

>Spring Boot 기반 단일 API 서비스에서   
>의도적 부하, 서킷 브레이커, 관측(Observability)을 실험하기 위한 백엔드 프로젝트

## 1. 프로젝트 목적

이 프로젝트는 단순 CRUD API가 아니라, 
1. 의도적으로 시스템 부하를 발생시키고
2. 서킷 브레이커가 언제 동작하는지 확인하며
3. Prometheus / Grafana로 상태를 시각화
4. Docker 단일 서버 환경에서의 한계를 체험

하는 것을 목적으로 한다.

> ⚠️ 성능 최적화가 목적이 아니고, “시스템이 망가지기 직전 어떤 일이 벌어지는지”를 관측하는 실험용 백엔드

---

## 2. 기술 스택
| 구분            | 기술                               |
| ------------- | -------------------------------- |
| Language      | Java 17                          |
| Framework     | Spring Boot **3.4.2**            |
| Build         | Gradle                           |
| DB            | PostgreSQL 16                    |
| Cache         | Redis 7                          |
| Resilience    | Resilience4j                     |
| Observability | Actuator, Micrometer, Prometheus |
| Infra         | Docker (단일 서버 기준)                |

---

## 3. 디렉토리 구조
```
services/service-a/backend/
├── build.gradle
├── .env
├── src/main/java/com/exit8/
│   ├── Application.java
│   │
│   ├── controller/
│   │   ├── SystemHealthController.java
│   │   ├── LoadScenarioController.java
│   │   └── CircuitBreakerTestController.java
│   ├── service/
│   │   ├── SystemHealthService.java
│   │   ├── LoadScenarioService.java
│   │   └── CircuitBreakerTestService.java
│   │
│   ├── repository/
│   │   ├── LoadTestLogRepository.java
│   │   ├── DummyDataRepository.java
│   │   └── SystemLogRepository.java 
│   ├── domain/
│   │   ├── LoadTestLog.java
│   │   ├── DummyDataRecord.java
│   │   └── SystemLog.java                     #  spring_logs
│   │
│   ├── dto/
│   │   ├── DefaultRequest.java
│   │   ├── DefaultResponse.java
│   │   ├── ErrorResponse.java
│   │   └── SystemHealthStatus.java
│   │
│   ├── exception/
│   │   ├── ApiException.java
│   │   └── GlobalExceptionHandler.java
│   │
│   ├── logging/
│   │   ├── LogAspect.java                     # 저장 트리거
│   │   ├── LogLevelPolicy.java                # 레벨 판단
│   │   ├── TraceIdGenerator.java              # trace_id 생성
│   │
│   └── config/
│       ├── datasource/
│       │   └── PostgresConfig.java
│       ├── redis/
│       │   └── RedisConfig.java
│       └── resilience/
│           └── CircuitBreakerConfig.java
│
└── src/main/resources/
    ├── application.yml
    ├── application-local.yml
    └── application-docker.yml

```
---
## 4. 실행 환경 분리 전략
### Profiles
- local : 로컬 개발 (DB/Redis는 Docker 컨테이너)
- docker : GCP 내부 Docker 네트워크

```
SPRING_PROFILES_ACTIVE=local ./gradlew bootRun
```
- Gradle bootRun에 기본값 local 설정됨
- 추후 Vault와 연동하면 달라질 수 있음 (.env) 

---

## 5. 데이터 계층 구성
### PostgreSQL

- 부하/실험 데이터는 운영 도메인과 분리
- JPA 사용
- ddl-auto: update (실험 단계)

| 테이블                       | 목적            |
| ------------------------- | ------------- |
| spring_load_test_logs     | 부하 테스트 결과     |
| spring_dummy_data_records | DB 부하용 더미 데이터 |
| spring_logs               | 시스템 로그 (후순위)  |

### Redis
- 현재는 캐싱 전략 적용 전 단계
- Key 네이밍 규칙
```
{service}:{app}:{resource}:{id}

# 예시
service-a-backend:spring:load:cpu
service-a-backend:spring:health:status
```
- 모든 Key는 TTL 필수
- 실험용 Key는 test: prefix 사용
---

## 6. API 분류

### Load & Experiment APIs
- 시스템에 의도적 부하를 가하는 API
- 모든 호출은 상태 변화를 유발함
- side-effect 존재 (DB/CPU/메트릭/서킷 상태 변화 발생)

### Health & Observability APIs
- 시스템 현재 상태 조회 API
- UI / Prometheus / 운영 연계
- side-effect 없음 (상태 조회 전용, read-only)

[postman API 명세서](https://documenter.getpostman.com/view/20595515/2sBXVo9nk7)

---

## 7. 부하 / 실험 API

### SystemHealthController
- UI 빠른 상태 확인용
- 상태 판단 기준
```
UP
- CircuitBreaker 상태: CLOSED
- DB 커넥션 풀: 정상 (Hikari validation warning 없음)

DEGRADED
- CircuitBreaker 상태: HALF_OPEN
- 또는 DB 커넥션 풀 경고 발생
  (HikariPool validation warning, 응답 지연 증가 등)

DOWN
- CircuitBreaker 상태: OPEN
- 핵심 기능 차단 상태

```

### LoadScenarioController
- POST만 사용
- 모든 결과는 spring_load_test_logs 저장
- 실험용이므로 상한값 강제 적용 (10_000)

#### 1) CPU 부하
- CPU saturation 상황 재현
- GC / 응답 지연 / CircuitBreaker 영향 관측
- sleep ❌ (스레드 블로킹만 발생)
- busy-loop 연산으로 실제 CPU 점유
- `durationMs <= 10000` 초과 시 ApiException

#### 2) DB READ 부하
- DB 커넥션 풀 고갈
- SELECT 병목 상황 관측
- DummyData 반복 SELECT
- 캐시 미적용 (추후 적용)
- **repeatCount 만큼 findById / findAll 반복**

#### 3) DB WRITE 부하
- WAL 증가
- 트랜잭션 누적 상황 재현
- DummyData INSERT 반복
- flush 전략은 기본값 유지 (추후 변경 가능)

### CircuitBreakerTestController
- CircuitBreaker가 언제 OPEN 되는지 눈으로 확인
- Fallback 동작 검증

#### 동작 방식
1. 내부에서 의도적으로 timeout 발생
2. Resilience4j가 실패 누적
3. OPEN 전환
4. Fallback 호출

---

## 8. Service 책임 원칙

### 기본 원칙
- Controller는 얇게 유지 → 요청 파라미터 바인딩 + Service 호출만 담당
- 모든 검증·제어는 Service 담당
- checked exception 외부 전파 ❌
- 부하 시나리오 = Service 책임

### UI ↔ API ↔ Service 정합성 원칙
- UI 버튼 · API 엔드포인트 · Service 메서드가 1:1로 매핑

| UI 버튼     | API                                         | Service                                                               |
| --------- | ------------------------------------------- | --------------------------------------------------------------------- |
| CPU 부하 시작 | `/api/load/cpu`                             | `LoadScenarioService.generateCpuLoad()`                               |
| DB 부하 시작  | `/api/load/db-read`<br>`/api/load/db-write` | `LoadScenarioService.simulateDbReadLoad()`<br>`simulateDbWriteLoad()` |
| 상태 표시     | `/api/system/health`                        | `SystemHealthService.getCurrentStatus()`                              |
| 차단 테스트    | `/api/circuit/test`                         | `CircuitBreakerTestService.callWithDelay()`                           |

### 규칙 강제 이유
1. 관측 가능성(Observability)
   - 로그, 메트릭, 트레이스가 Service 단위로 정확히 분리
2. 부하 시나리오 단순화
   - “어떤 버튼이 어떤 부하를 만들었는지” 즉시 추적 가능
3. UI ↔ 백엔드 커뮤니케이션 명확화
   - UI 팀 / 인프라 팀 / 백엔드 팀 간 오해 제거
4. AOP 로깅 구조와 완벽하게 호환
   - Service.*(..) 기준으로 로깅 / 시간 측정 / 실패 감지 가능

---

## 9. 공통 응답 포맷
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
| DB 병목                | 200 + DEGRADED |
| 잘못된 파라미터             | 400            |

---

## 10. 로깅 전략 (핵심)
### 원칙
- Service / Controller에 로그 ❌
- AOP(LogAspect)로만 로깅
- trace_id 기반 요청 추적
- 로그 레벨 판단 중앙화

#### LogAspect
- LOAD_START
- LOAD_END
- LOAD_FAIL / LOAD_ERROR

#### TraceIdGenerator
- 요청 단위 trace_id 생성
- MDC 기반
- 요청 종료 시 clear

#### LogLevelPolicy
- Circuit OPEN → WARN
- DB / I/O → ERROR
- 추후 CRITICAL 확장 가능

---

## 11. Docker 기반 개발 환경

### Spring Boot 애플리케이션 Docker 이미지화
- Gradle 기반 Spring Boot 애플리케이션을 Docker 이미지로 패키징
- 빌드 단계와 실행 단계를 분리한 **Multi-stage 빌드 적용으로 이미지 용량 최소화**
- 최종 이미지에는 실행에 필요한 JAR 파일만 포함
- Build Stage
  - eclipse-temurin:17-jdk-alpine 기반
  - Gradle Wrapper를 사용하여 애플리케이션 빌드
- Runtime Stage
  - 빌드 단계에서 생성된 JAR만 복사하여 실행
  - curl을 설치하여 /actuator/health 기반 Docker Healthcheck 지원
- Docker Healthcheck와 Spring Actuator를 연계한 컨테이너 생존 상태 확인 가능

### Docker Healthcheck & Spring Actuator 설계 원칙
- docker-compose를 수정하지 않는 것을 전제로 Spring Actuator Health 동작 설계
- docker-compose Healthcheck는 /actuator/health 기준으로 HTTP 응답 가능 여부(Liveness) 만 판단
```
healthcheck:
  test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080/actuator/health"]
```

### Docker 환경 Health 정책 (application-docker.yml)
```
management:
  health:
    db:
      enabled: false
    redis:
      enabled: false
    circuitbreakers:
      enabled: false
```
- DB / Redis / CircuitBreaker 상태는 Health 판단에서 제외
- 부하 테스트 중 의존성 장애가 발생해도 컨테이너 유지
- restart loop 방지

| 레이어             | Health 의미            |
| --------------- | -------------------- |
| Docker          | 프로세스 + HTTP 응답 여부    |
| Spring (docker) | Liveness             |
| 관측              | Prometheus / Grafana |


---
## 12. 로컬 Docker 테스트 절차

### DB 컨테이너 실행
- PostgreSQL
```
docker run -d --name postgres --network exit8-net -p 5432:5432 -e POSTGRES_DB=EXIT8 -e POSTGRES_USER=exit8 -e POSTGRES_PASSWORD=exit8pass postgres:16
```

- Redis
```
docker run -d --name redis --network exit8-net -p 6379:6379 redis:7
```

### SpringBoot 서버 도커라이징

1. Gradle Wrapper를 제대로 생성해서 Git에 포함
```
.\gradlew.bat wrapper --gradle-version 8.5
```

2. 이미지 빌드 (캐시 제거)
```
docker build --no-cache -t service-a-backend:test .
```

3.  실행
```
docker run -d \
  --name service-a-backend \
  -p 8080:8080 \
  --network exit8-net \
  -e SPRING_PROFILES_ACTIVE=docker \
  service-a-backend:test
```

4. 확인
```
curl http://localhost:8080/actuator/health
```

- 정상 응답 예:
```
{"status":"UP"}
```

### 공용 네트워크 생성
```
docker network create exit8-net
```

- 기존 DB 컨테이너를 네트워크에 연결
```
docker network connect exit8-net postgres
docker network connect exit8-net redis
```

- backend 실행 (같은 네트워크)
```
docker run --name service-a-backend -p 8080:8080 --network exit8-net -e SPRING_PROFILES_ACTIVE=docker service-a-backend:test
```
---

## 13. 앞으로의 확장 / 완료 현황 정리

### ✅ 이미 완료된 항목
1. Resilience4j 기반 차단 시나리오
   - CircuitBreaker 설정 완료 (testCircuit)
   - OPEN / HALF_OPEN / CLOSED 상태 전이 확인
   - Fallback 메시지 고정
2. OPEN 시 WARNING 로그 정책 적용
   - 부하 테스트 시나리오
   - CPU busy-loop 기반 부하 (/api/load/cpu)
   - DB READ 반복 부하 (/api/load/db-read)
   - DB WRITE 반복 부하 (/api/load/db-write)
3. 모든 실행 결과 spring_load_test_logs 저장
   - Observability 기본 구성
   - Spring Boot Actuator 적용
   - Micrometer + Prometheus 연동
   - `/actuator/health`
   - `/actuator/prometheus`
   - API 호출 지연 / 부하 상황 Prometheus 수집 가능
4. AOP 기반 로깅 구조
   - Service / Controller 직접 로그 제거
   - `LogAspect` 단일 진입점 로깅
   - LOAD_START / LOAD_END / LOAD_FAIL 패턴 확립
   - 실행 시간 기반 로그 기록
5. 응답 포맷 및 예외 처리 표준화
   - DefaultResponse<T> 공통 응답 포맷
   - ApiException + GlobalExceptionHandler
   - Error code / message 분리
6. 환경 분리 전략
   - application.yml (공통)
   - application-local.yml
   - application-docker.yml
   - SPRING_PROFILES_ACTIVE 기반 실행
   - Gradle bootRun 기본값 local 설정

### ⏳ 아직 진행하지 않은 항목
1. spring_logs 테이블 실제 연동
   - 현재는 Logback / 콘솔 중심
   - DB 로그 저장은 구조(AOP, 정책, 도메인) 만 설계된 상태
   - LogAspect → SystemLog 저장
   - 배치 기반 백업 후 truncate 전략 적용
2. JSON Logback 적용
   - ELK / Loki 연계 전제
   - 현재는 텍스트 로그로 실험 집중
   - logstash-logback-encoder 적용
   - trace_id / level / duration / scenario 필드 구조화
3. Vault 연동
   - DB / Redis 자격 증명 동적 로딩
   - 보안 파트 연계 이후 적용 예정
   - 현재는 .env + profile 기반으로 단순화
   - Spring Cloud Vault Client 적용
   - Secret rotation 시나리오 실험
4. Prometheus Exporter
   - 현재: Actuator 기본 메트릭 + 일부 커스텀
   - 미완: HTTP 요청 수 / 응답 시간 세분화, CircuitBreaker 상태 메트릭 명시적 노출
   - 추후: custom meter (Timer / Counter) 추가
5. DB 백업 시나리오
   - 로그 정리 주기
6. 부하 테스트 실행
   - 현재: 부하 유발 API만 구현
   - 미완: 외부 부하 도구 연계
   - 추후: JMeter / Locust 활용, 동시 사용자 증가에 따른 DB 풀 고갈, CircuitBreaker OPEN 시점 분석
7. Redis 캐싱 적용
   - READ 시 캐싱 또는 Read Replica + 캐시 비교 실험
8. Spring Security 도입 (프론트엔드 연동 전 필수)
   - 프론트엔드(UI)와 연동 시 무제한 호출 / 오남용 방지
   - 실험 API 보호
   - 운영 환경을 흉내 내기 위한 최소한의 보안 레이어 적용
---
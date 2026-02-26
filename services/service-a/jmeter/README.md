# JMeter – External Abnormal Traffic Generator for Service-A

> 외부 비정상 트래픽을 발생시키기 위한 JMeter 전용 구성이다.   
> 애플리케이션 성능 측정이 아닌, 운영 장애 상황 재현 및 방어 기법 검증을 목적으로 한다.

## 1. 목적

### 비정상 트래픽 유입 시 확인 대상
- 시스템 병목 발생 지점
- Rate Limit / Circuit Breaker의 실제 보호 효과
- DB Connection Pool(50)의 임계 구간에 도달하는 수준의 동시 요청을 단계적으로 유입
  
---

## 2. 논리적 위치
- JMeter는 애플리케이션 구성 요소가 아니다.
- JMeter는 외부 행위자(External Actor) 로 간주한다.
- JMeter는 로컬/외부 환경에서 실행되며 공인 네트워크 경로를 통해 타겟 게이트웨이로 요청을 보낸다.
- Backend Service와는 제어·권한·코드가 분리되어 있으며, 요청/응답 트래픽만 교환한다.
```
JMeter (External Actor)
  → Gateway (Public Listener)
  → Backend Service (Target)
```
> Gateway는 Nginx / NPM / 별도 Reverse Proxy 컨테이너 등으로 구현될 수 있다.   
> 테스트 타겟은 “Backend 직접 포트”가 아니라 “Gateway의 외부 리슨 포트”로 고정한다.


※ 현재 실험 환경 기준
- Gateway: loadtest-gw (8081)  또는  NPM (80/443)
- Backend 직접 포트(8080)는 실험 대상이 아니다.

---

## 3. 동작 원리 (3 Pillars)

### What
```
# READ
POST /api/load/db-read?repeatCount=1

# WRITE
POST /api/load/db-write?repeatCount=1
```
- READ / WRITE는 서로 다른 실험 시나리오로 분리한다. 
- 하나의 실험 시나리오에서는 단일 **Target API(Endpoint)**만 측정한다. 
- 단, 해당 시나리오 내에는 부하를 유발하는 Attack-TG와 가용성을 체크하는 Normal-TG가 공존한다.
- Target Method는 `POST`로 고정한다. (GET 호출 시 405 발생)

### How many
- 동시 가상 사용자 수 (Thread 수)

### How long
- 요청 간격 및 유지 시간
- 기본 실험(Concurrency Stress Test)의 부하 강도는 Threads 수로 제어한다.
- 단, DB 내부 자원 고갈(Resource Exhaustion) 실험에서는 요청 1건당 자원 점유 시간을 증가시키기 위해 repeatCount를 보조적으로 사용할 수 있다.
- repeatCount는 동시성 증가 수단이 아니라 요청 1건당 내부 작업량(점유 시간)을 증가시키는 보조 수단이다.
- 동일 조건 비교 실험에서는 repeatCount를 반드시 고정값으로 유지한다.
---

## 4. 주요 구성 요소

### Thread Group
- Thread: 가상의 사용자 1명
- Thread Group: 동시에 요청을 보내는 사용자 집단
```
100 Threads = 100명의 동시 요청
```

### HTTP Request
- 동일한 API / Method / 파라미터 사용
- `X-Forwarded-For` 헤더로 IP 구분하여 분리
  - 공격자 트래픽(Attack)
  - 정상 사용자 트래픽(Normal)

### Listener
- Non-GUI 모드로 실행
- 결과는 CSV(.jtl) 파일로 저장 후 HTML 리포트로 분석

---

## 5. 공격 트래픽 vs 정상 트래픽

| 구분       | Attack-TG   | Normal-TG                     |
| ---------- | -------- | ----------------------------- |
| 목적       | 부하 유발   | 가용성 확인                  |
| Thread 수  | 많음  | 적음                          |
| 요청 간격  | DB Pool(50) 임계 탐색 기준에 맞춰 설정  | 일정 (예: 1000ms)  |
| IP         | 동일   | 다름     |
| Header     | X-Forwarded-For: 10.10.10.10  | X-Forwarded-For: 20.20.20.20 |

- 두 그룹은 같은 API, 같은 파라미터를 사용한다.
- 차이는 **동시성(Thread), 요청 간격(Delay), IP**만 존재한다.
> Concurrency Stress Test에서는 Delay 0ms를 금지한다.   
> (단, Resource Exhaustion Test에서는 예외적으로 Delay 0ms를 허용한다.)

#### 구조 예시

```
Attack-TG
- threads: 30 → 45 → 50 → 60 → 80 → 100
- ramp-up: 20~30s
- delay:
    READ  = 100~200ms
    WRITE = 150~300ms
- loop: 50 (또는 단계별 2~3분 유지)

Normal-TG
- threads: 1~3
- delay: 1000ms
- loop: 50

```

※ Resource Exhaustion Test에서는 다음이 추가로 허용된다.
- repeatCount 증가
- Delay 0ms
- Pool Size 축소

---

## 6. 디렉터리 구조
```
services/service-a/
├── backend/          # 실험 대상 (Spring Boot)
└── jmeter/           # 외부 비정상 트래픽 발생자
    ├── Dockerfile
    └── scenarios/    # JMeter .jmx 시나리오
```

## 7. 실험 제약 조건

### Concurrency Stress Test (기본 실험)

1. 목적
   - 동시 요청 증가에 따른 임계 구간 탐색
   - Rate Limit / CircuitBreaker 보호 효과 검증
2. 제약
   - repeatCount = 1 (고정)
   - DB Pool = 50 (기본값)
   - Delay = 0ms 금지
   - Thread 수만 단계적으로 증가
   - ON/OFF 비교는 동일 Thread 단계에서만 수행

### Resource Exhaustion Test (고갈 유도 실험)
1. 목적
   - DB Connection Pool 고갈 상황 강제 재현
   - 내부 대기열 증가 및 timeout 발생 관측
   - 방어 기제의 극한 상황 보호 능력 확인
2. 허용 사항
   - repeatCount > 1 허용
   - DB Pool Override 허용 `-Dspring.datasource.hikari.maximum-pool-size=5`
   - Delay 0ms 허용
   - Ramp-up 단축 허용
3. 제약
   - Concurrency Stress Test 결과와 직접 비교하지 않는다.
   - 고갈 실험은 “임계점 재현” 목적이며 성능 비교 목적이 아니다.

---

## 8. Docker 기반 실행
### JMeter Dockerfile
```
FROM --platform=linux/amd64 eclipse-temurin:17-jdk-alpine

ARG JMETER_VERSION=5.6.3

# apt-get 대신 apk 사용, bash 추가 설치
RUN apk update && apk add --no-cache curl unzip bash \
    && curl -L https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-${JMETER_VERSION}.tgz \
       -o /tmp/jmeter.tgz \
    && tar -xzf /tmp/jmeter.tgz -C /opt \
    && rm /tmp/jmeter.tgz

ENV JMETER_HOME=/opt/apache-jmeter-${JMETER_VERSION}
ENV PATH=$JMETER_HOME/bin:$PATH

WORKDIR /jmeter

CMD ["bash", "-c", "while true; do sleep 3600; done"]
```

### docker-compose 예시
```
services:
  backend:
    build: ./backend
    ports:
      - "8080:8080"

  jmeter:
    build: ./jmeter
    volumes:
      - ./jmeter/scenarios:/jmeter/scenarios
      - ./jmeter/results:/jmeter/results
```
- backend 컨테이너에 docker.sock 마운트 없음
- backend ↔ jmeter 간 제어 관계 없음

---

## 9. 실행 시나리오
1. UI에서 “실험 시작” 트리거 발생 (선택)
2. Backend는 실험 시작 상태만 기록 (선택)
3. JMeter 컨테이너 실행
4. JMeter가 외부 공격자 역할로 Gateway(Public Listener) 로 트래픽 유입
5. backend는 Rate Limit / Circuit Breaker로 대응

---

## 10. 로그
### CLI에서 필드 제한
- JMeter는 저장 필드를 -J 옵션으로 줄일 수 있다.

### 권장 최소 필드
1. timeStamp
2. elapsed
3. label
4. responseCode
5. success
6. threadName
7. latency
8. connectTime

### 실험 단계별 파일 분리
```
read_result_60.jtl
write_result_40.jtl
```

---

## 11. JMeter .jmx 파일
### attack_read_vs_normal.jmx

> DB READ 기반 부하 상황

1. 관측 요소
   - 동시 요청 증가에 따른 응답 지연
   - Thread Pool / DB Connection Pool 병목
   - CircuitBreaker OPEN 시점

2. 실험 구성
   - Attack / Normal 트래픽 동시 실행
   - API / 파라미터 완전 동일

3. 차이 요소
   - Thread 수
   - 요청 간격
   - IP

4. 비교 포인트
   - Rate Limit 적용 전·후 정상 트래픽 보호 여부
   - CircuitBreaker 동작 여부

### attack_write_vs_normal.jmx

> DB WRITE 기반 부하 상황

1. 관측 요소
   - 락 경합
   - Commit 비용 증가
   - 급격한 병목 발생 양상

2. 실험 구성
   - Attack / Normal 트래픽 동시 실행
   - API / 파라미터 완전 동일

3. 차이 요소
   - Thread 수
   - 요청 간격
   - IP

4. 비교 포인트
   - Rate Limit 적용 전·후 쓰기 병목 완화 효과
   - CircuitBreaker 동작 여부


### 두 시나리오의 차이
> 부하= Thread 수 × 요청 간격 × 실험 시간   
> Concurrency Stress Test에서는 repeatCount = 1로 통일한다 (Resource Exhaustion Test는 예외)


| 항목          | READ            | WRITE         |
| ----------- | --------------- | ------------- |
| API         | `/db-read`      | `/db-write`   |
| 병목          | Connection Pool | Lock / Commit |
| 장애 양상       | 점진적 지연     | 급격한 병목     |


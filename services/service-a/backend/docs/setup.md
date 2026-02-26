# 실행 환경 구성 및 인프라 연동
> 실행 프로필 및 Docker/Vault 기반 개발 환경 구성 가이드

---

## 1. 실행 환경 분리 전략
### Profiles
- local : 로컬 개발 (DB/Redis는 Docker 컨테이너)
- docker : Docker 네트워크 기반 실행 환경 (컨테이너 간 통신 전제)

```
SPRING_PROFILES_ACTIVE=local ./gradlew bootRun
```
- Gradle `bootRun` 기본 프로필은 `local`
- 실행 환경 구분은 `SPRING_PROFILES_ACTIVE` 기준
- Vault 연동 여부와 관계없이 프로필 전략은 동일
- Vault 접근 정보는 실행 시점에 환경 변수로 주입

---

## 2. Docker 기반 개발 환경

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

<br>

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
  - Docker Health는 **프로세스 생존 여부**만 판단
  - DB 장애나 Circuit OPEN은 컨테이너 재시작 조건 X
- 부하 테스트 중 의존성 장애가 발생해도 컨테이너 유지
- restart loop 방지
- application.yml에는 health 판단 로직을 두지 않음
- health의 의미는 profile별로 완전히 다르게 정의됨
- docker 환경에서는 관측 정보(state, details)를 노출하지 않음
- liveness 판단과 observability를 명확히 분리하기 위함

| 레이어             | Health 의미            |
| --------------- | -------------------- |
| Docker          | 프로세스 + HTTP 응답 여부    |
| Spring (docker) | Liveness             |
| 관측              | Prometheus / Grafana |

> ※ CircuitBreaker OPEN 상태에서도 Docker Health는 정상으로 판단된다.

---

## 3. 필수 환경 변수

- 로컬 실행 시 `.env.example`을 복사해 `.env`로 만든 뒤 실행 필요

### 기본 (Vault Dev Token 방식)
| 변수 | 설명 |
|------|------|
| SPRING_PROFILES_ACTIVE | 실행 프로필 (`local` / `docker`) |
| VAULT_URI | Vault 서버 주소 (예: `http://vault:8200`) |
| VAULT_TOKEN | Vault 접근 토큰 (dev 모드: `root-token`) |

### (선택) AppRole 방식 사용 시

> 이 프로젝트 기본 범위에서는 사용하지 않으며, 운영 고도화 단계에서만 고려

| 변수 | 설명 |
|------|------|
| VAULT_ROLE_ID | AppRole Role ID |
| VAULT_SECRET_ID | AppRole Secret ID |


---

##  4. 로컬 Docker 테스트 절차

### 공용 네트워크 및 볼륨 생성
```
# 네트워크 생성
docker network create frontend || true
docker network create backend || true
docker network create db || true

# 데이터 보존을 위한 볼륨 생성 (필요 시)
docker volume create postgres_data
docker volume create redis_data
```

<br>

### DB 및 인프라 컨테이너 실행
- PostgreSQL
```
# 테스트 환경 전용 설정 (운영에서는 절대 사용 금지)
docker run -d --name postgres \
  --network db \
  -p 5432:5432 \
  -e POSTGRES_DB=appdb \
  -e POSTGRES_HOST_AUTH_METHOD=trust \
  postgres:16-alpine

docker exec -it postgres psql -U postgres -d appdb

# (컨테이너 내부에서 실행)
-- 로그인 가능한 유저 생성
CREATE USER admin WITH PASSWORD 'password_입력';

-- DB 접근 권한 부여
GRANT CONNECT ON DATABASE appdb TO admin;

-- public 스키마 사용 권한
GRANT USAGE, CREATE ON SCHEMA public TO admin;
```

- Redis
```
docker run -d --name redis \
 --network db -p 6379:6379 redis:7-alpine redis-server \
 --maxmemory 256mb --maxmemory-policy allkeys-lru
```

- Vault
```
docker run -d --name vault \
  -p 8200:8200 --network backend \
  -e VAULT_DEV_ROOT_TOKEN_ID=root-token \
  -e VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200 hashicorp/vault:1.15

# Vault dev 모드 토큰: root-token
docker exec -it vault sh

# (컨테이너 내부에서 실행)
# KV 세팅
vault kv put secret/exit8 \
  db.username=admin \
  db.password=password_입력
```
> Spring Cloud Vault는 `secret/exit8` 경로를 PropertySource로 로드하며  
> `db.username`, `db.password` 값을 `spring.datasource.*`에 매핑한다.

<br>

### SpringBoot 서버 도커라이징

1. Gradle Wrapper를 제대로 생성해서 Git에 포함
```
# Windows
.\gradlew.bat wrapper --gradle-version 8.5

# Linux/Mac
./gradlew wrapper --gradle-version 8.5
```

2. 이미지 빌드 (캐시 제거)
```
docker build --no-cache -t exit8/service-a-backend:test .
```

3. 실행
> 주의: Vault를 기동 시점에 반드시 로드하는 설정이라면, 컨테이너 시작 직후 Vault 네트워크가 연결되어 있어야 한다.

```
# 1. 기존에 죽어있는 컨테이너 삭제
docker rm -f service-a-backend

# 2. .env 로 전체 환경변수를 주입
docker run -d \
  --name service-a-backend \
  -p 8080:8080 \
  --network db \
  --env-file .env \
  -e JAVA_OPTS="-Xms256m -Xmx512m" \
  exit8/service-a-backend:test

# 3. 네트워크 추가 연결 (멀티 네트워크 설정)
docker network connect backend service-a-backend
```

4. 확인
```
curl http://localhost:8080/actuator/health
```

- 정상 응답 예:
```
{"status":"UP"}
```

---
# ---------- build stage ----------
FROM eclipse-temurin:17-jdk-alpine AS build

WORKDIR /app

# Gradle 캐시 최적화
COPY gradlew .
COPY gradlew.bat .
COPY gradle gradle
COPY build.gradle settings.gradle ./

RUN sed -i 's/\r$//' gradlew
RUN chmod +x gradlew

RUN ./gradlew dependencies --no-daemon

# 실제 소스
COPY src src

RUN ./gradlew bootJar --no-daemon

# ---------- runtime stage ----------
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# 비root 사용자 생성 (Alpine 명령어 사용)
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# curl 설치 (healthcheck용)
RUN apk add --no-cache curl

# Spring Boot bootJar 복사
COPY --from=build --chown=appuser:appgroup /app/build/libs/*.jar app.jar

# 비root 사용자로 전환
USER appuser

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]

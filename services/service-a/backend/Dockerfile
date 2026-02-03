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

RUN groupadd -g 1001 appgroup && \
    useradd -u 1001 -g appgroup -s /bin/bash appuser

# 실제 소스
COPY src src

RUN ./gradlew bootJar --no-daemon

# ---------- runtime stage ----------
FROM eclipse-temurin:17-jre-alpine

USER appuser

WORKDIR /app

RUN apk add --no-cache curl

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# Spring Boot bootJar만 명시적으로 사용
COPY --from=build /app/build/libs/*.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]

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

# Spring Boot bootJar만 명시적으로 사용
COPY --from=build /app/build/libs/*.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]

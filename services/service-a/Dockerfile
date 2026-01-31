# ==========================================
# Service A: Spring Boot Backend
# ==========================================

# Stage 1: Build Backend
FROM eclipse-temurin:25-jdk-alpine AS backend-build
WORKDIR /app
COPY backend/ ./
RUN chmod +x gradlew && ./gradlew bootJar --no-daemon

# Stage 2: Production Image
FROM eclipse-temurin:25-jre-alpine
WORKDIR /app

# Copy backend JAR
COPY --from=backend-build /app/build/libs/*.jar app.jar

# Copy frontend static files
COPY frontend/ /app/static/

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD wget -q --spider http://localhost:8080/health || exit 1

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]

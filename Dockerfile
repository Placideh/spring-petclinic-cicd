# =========================
# Build Stage for IMAGE
# =========================
FROM eclipse-temurin:21-jdk-alpine AS builder
# Set work directory
WORKDIR /app
# Copy Maven wrapper and pom.xml first for better layer caching
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
# Ensure mvnw has execute permission
RUN chmod +x mvnw
# Download dependencies (cached layer if pom.xml doesn't change)
RUN ./mvnw dependency:go-offline -B
# Copy source code
COPY src ./src
# Build the project
RUN ./mvnw clean package -DskipTests
# Verify JAR was created
RUN ls -lh target/*.jar
# =========================
# Runtime Stage
# =========================
FROM eclipse-temurin:21-jre-alpine
# Add labels for better image management
LABEL maintainer="hup@andrew.cmu.com"
LABEL application="spring-petclinic"
LABEL description="Spring PetClinic CI/CD Pipeline"
# Set work directory
WORKDIR /app
# Create non-root user for security best practices
RUN addgroup -S spring && \
    adduser -S spring -G spring && \
    chown -R spring:spring /app
# Copy the packaged jar from the builder stage
COPY --from=builder --chown=spring:spring /app/target/*.jar app.jar
# Switch to non-root user
USER spring:spring
# Expose application port
EXPOSE 8080
# Add health check for container orchestration
HEALTHCHECK --interval=30s \
            --timeout=3s \
            --start-period=60s \
            --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1
# Set JVM options for containerized environments
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -Djava.security.egd=file:/dev/./urandom"
# Run the application
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]


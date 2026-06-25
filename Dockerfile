# ==========================================
# Stage 1: Build and Extract Layers
# ==========================================
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /build

# 1. Copy build configuration files first to leverage Docker layer caching
COPY .mvn/ .mvn
COPY mvnw pom.xml ./

# 2. Download dependencies (this layer stays cached unless pom.xml changes)
RUN ./mvnw dependency:go-offline

# 3. Copy source code and build the application package
COPY src ./src
RUN ./mvnw clean package -DskipTests

# 4. Extract application layers using Spring Boot's built-in tool
RUN java -Djarmode=layertools -jar target/*.jar extract

# ==========================================
# Stage 2: Final Lightweight Runtime Image
# ==========================================
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Create a non-root system user for security
RUN addgroup -S spring && adduser -S spring -G spring

# 5. Copy extracted layers from the builder stage
# Dependencies change the least, application classes change the most
COPY --from=builder /build/dependencies/ ./
COPY --from=builder /build/spring-boot-loader/ ./
COPY --from=builder /build/snapshot-dependencies/ ./
COPY --from=builder /build/application/ ./

# Switch to the non-root user
USER spring:spring

# Expose the application port
EXPOSE 8080

# 6. Run the application using the Spring Boot JarLauncher
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]

# syntax=docker/dockerfile:1

# Use Eclipse Temurin 21 JRE on Alpine (not Debian)
# Alpine provides minimal attack surface and smaller image size
FROM eclipse-temurin:21-jre-alpine

# Metadata labels following OCI image spec
LABEL org.opencontainers.image.title="Minecraft Server"
LABEL org.opencontainers.image.description="Dockerized Minecraft server with automatic RAM detection and Aikar's flags"
LABEL org.opencontainers.image.vendor="docker-minecraft"
LABEL org.opencontainers.image.licenses="MIT"

# Install runtime dependencies
# Combining into single layer for optimization
RUN apk add --no-cache \
    bash \
    curl \
    && rm -rf /var/cache/apk/*

# Create non-root user for security
# Using specific UID/GID for consistency across deployments
RUN addgroup -g 1000 minecraft \
    && adduser -D -u 1000 -G minecraft minecraft

# Set working directory
WORKDIR /server

# Change ownership to minecraft user
RUN chown -R minecraft:minecraft /server

# Switch to non-root user
USER minecraft

# Expose Minecraft server port
EXPOSE 25565

# Expose RCON port (optional remote console)
EXPOSE 25575

# Set default command
CMD ["bash", "/server/start.sh"]

# Healthcheck (can be overridden in docker-compose.yml)
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD nc -z localhost 25565 || exit 1

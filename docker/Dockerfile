# syntax=docker/dockerfile:1

# Use Eclipse Temurin 21 JRE on Alpine (not Debian)
# Alpine provides minimal attack surface and smaller image size
FROM eclipse-temurin:21-jre-alpine

# Metadata labels following OCI image spec
# See: https://github.com/opencontainers/image-spec/blob/main/annotations.md
LABEL org.opencontainers.image.title="Minecraft Server" \
      org.opencontainers.image.description="Dockerized Minecraft server with automatic RAM detection and Aikar's flags" \
      org.opencontainers.image.vendor="docker-minecraft" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/secondfry/docker-minecraft" \
      org.opencontainers.image.documentation="https://github.com/secondfry/docker-minecraft/blob/main/README.md"

# Install runtime dependencies
# Sorted alphabetically per Docker best practices for easier maintenance
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

# Switch to non-root user
# Note: Volume mounts override image layers, so we don't chown here.
# Host files must be readable by UID 1000 or use an entrypoint to fix permissions.
USER minecraft

# Expose Minecraft server port
EXPOSE 25565

# Note: RCON port (25575) not exposed by default for security
# Uncomment in docker-compose.yml only if you need remote console access

# Set default command
CMD ["bash", "/server/start.sh"]

# Signal handling for graceful shutdown
STOPSIGNAL SIGTERM

# Healthcheck (can be overridden in docker-compose.yml)
# Uses bash's built-in /dev/tcp for port checking (no netcat needed)
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD timeout 5 bash -c '</dev/tcp/localhost/25565' || exit 1

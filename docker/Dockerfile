# Use Eclipse Temurin 21 on Alpine (not Debian)
FROM eclipse-temurin:21-jre-alpine

# Install bash (Alpine uses sh by default) and other utilities
RUN apk add --no-cache bash curl

# Create minecraft user and group
RUN addgroup -g 1000 minecraft && \
    adduser -D -u 1000 -G minecraft minecraft

# Set working directory
WORKDIR /server

# Change ownership to minecraft user
RUN chown -R minecraft:minecraft /server

# Switch to minecraft user
USER minecraft

# Expose Minecraft server port
EXPOSE 25565

# Expose RCON port (if needed)
EXPOSE 25575

# Set default command
CMD ["bash", "/server/start.sh"]

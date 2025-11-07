# Docker Minecraft Server

Dockerized Minecraft Fabric server with optimized JVM settings using Eclipse Temurin and Aikar's flags.

## Prerequisites

- Docker and Docker Compose
- Your Minecraft server JAR file (Fabric, Paper, etc.)

## Project Structure

```
.
├── docker/                  # Docker build context (isolated from server files)
│   ├── Dockerfile          # Container image definition
│   └── .dockerignore       # Files to exclude from build
├── docker-compose.yml      # Service orchestration
├── start.sh                # Server startup script with optimized JVM flags
├── *.jar                   # Your Minecraft server JAR
└── [server files]          # World data, configs, mods, etc.
```

## Quick Start

1. **Place your server JAR** in the root directory:
   ```bash
   # Example for Fabric:
   wget https://meta.fabricmc.net/v2/versions/loader/1.21.8/0.17.0/1.1.0/server/jar \
     -O fabric-server-mc.1.21.8-loader.0.17.0-launcher.1.1.0.jar
   ```

2. **Update start.sh** (if needed) to point to your JAR file

3. **Build and start** the server:
   ```bash
   docker-compose up -d
   ```

4. **View logs**:
   ```bash
   docker-compose logs -f
   ```

## Configuration

### Memory Allocation

The default configuration allocates 6GB RAM. To change this:

1. Edit `start.sh` and modify `-Xms` and `-Xmx` values
2. Edit `docker-compose.yml` and update memory limits:
   ```yaml
   deploy:
     resources:
       limits:
         memory: 8G  # Should be Xmx + 1-2GB overhead
       reservations:
         memory: 6G  # Should match Xmx
   ```

### Ports

- `25565` - Minecraft server (default)
- `25575` - RCON (optional, for remote console)

## JVM Optimization

This setup uses **Aikar's flags** - industry-standard JVM optimizations for Minecraft:

- **G1GC** garbage collector for low-latency pauses
- Optimized for Minecraft's high memory allocation rate (~800MB/s)
- Tuned for 6GB RAM allocation
- 30-40% new generation sizing
- MaxTenuringThreshold=1 for transient objects

Reference: https://docs.papermc.io/paper/aikars-flags/

## Docker Commands

```bash
# Start server
docker-compose up -d

# Stop server
docker-compose down

# Restart server
docker-compose restart

# View logs
docker-compose logs -f

# Access console (interactive)
docker attach minecraft-server
# Press Ctrl+P, Ctrl+Q to detach without stopping

# Rebuild after config changes
docker-compose up -d --build
```

## Technical Details

- **Base Image**: Eclipse Temurin 21 JRE on Alpine Linux
- **User**: Runs as non-root `minecraft` user (UID 1000)
- **Volume Mount**: Current directory mounted at `/server`
- **Auto-restart**: Enabled (unless manually stopped)
- **Healthcheck**: Monitors port 25565 every 30 seconds

## File Structure Benefits

The `docker/` subdirectory isolates Docker build files from server data:
- **Faster builds**: Only Docker files are sent to build context
- **No pollution**: World data, logs, and JARs stay out of build process
- **Cleaner**: Separation of concerns between infrastructure and server data

## Troubleshooting

**Server won't start:**
- Check logs: `docker-compose logs`
- Verify JAR filename in `start.sh` matches your file
- Ensure ports 25565/25575 aren't already in use

**Out of memory:**
- Increase `-Xmx` in `start.sh`
- Update Docker memory limits in `docker-compose.yml`
- Leave 1-2GB overhead above `-Xmx` value

**Permission issues:**
- Container runs as UID 1000
- Ensure files are readable: `chmod -R 755 .`

## License

This Docker configuration is provided as-is. Minecraft server software has its own licenses.

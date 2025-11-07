# Docker Minecraft Server

Dockerized Minecraft server with **automatic RAM detection** and Aikar's optimized JVM flags.

Features Eclipse Temurin 21 JRE on Alpine Linux with intelligent memory management.

## Prerequisites

- Docker and Docker Compose
- Your Minecraft server JAR file (Fabric, Paper, Vanilla, etc.)
- Minimum 6GB RAM recommended (8GB+ preferred)

## Quick Start

1. **Place your server JAR** in the root directory:
   ```bash
   # Example for Fabric:
   wget https://meta.fabricmc.net/v2/versions/loader/1.21.8/0.17.0/1.1.0/server/jar \
     -O fabric-server-mc.1.21.8-loader.0.17.0-launcher.1.1.0.jar
   ```

2. **Build and start** the server (RAM auto-detected):
   ```bash
   docker-compose up -d
   ```

3. **View logs** to see detected configuration:
   ```bash
   docker-compose logs -f
   ```

That's it! The server automatically detects available RAM and configures itself.

## Memory Management

### Automatic Detection (Default)

The server **automatically detects available RAM** and configures JVM heap size with proper overhead:

| Total RAM | Heap Allocation | OS Overhead |
|-----------|-----------------|-------------|
| 6-7 GB    | Total - 1 GB    | 1 GB        |
| 8-15 GB   | Total - 2 GB    | 2 GB        |
| 16+ GB    | Total - 2 GB    | 2 GB        |

**Example**: On an 8GB system, the server allocates 6GB to Java and leaves 2GB for the OS.

### Manual Override

#### Option 1: Environment Variable (Recommended)

Edit `docker-compose.yml` and uncomment the `MEMORY_GB` line:

```yaml
environment:
  - TZ=UTC
  - MEMORY_GB=6  # Heap size in GB (without 'G' suffix)
```

Then restart: `docker-compose up -d`

#### Option 2: Edit start.sh (Persistent)

If you upgrade your server's RAM later, edit `start.sh` lines 26-28:

```bash
if [ -n "$MEMORY_GB" ]; then
    HEAP_SIZE="${MEMORY_GB}G"
    echo "Using manually configured memory: ${HEAP_SIZE}"
```

Change to:
```bash
if [ -n "$MEMORY_GB" ]; then
    HEAP_SIZE="10G"  # Your desired heap size
    echo "Using manually configured memory: ${HEAP_SIZE}"
```

**Important**: Always leave 1-2GB overhead! For 16GB total RAM, use 14GB heap maximum.

### Docker Memory Limits

Set container memory limits in `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      memory: 8G   # Maximum container can use
    reservations:
      memory: 6G   # Minimum to reserve
```

**Recommendation**: Set `limits.memory` to your host's total available RAM. The startup script will automatically calculate the appropriate heap size within that limit.

## Project Structure

```
.
├── docker/                  # Docker build context (isolated from server files)
│   ├── Dockerfile          # Container image definition
│   └── .dockerignore       # Files to exclude from build
├── docker-compose.yml      # Service orchestration
├── start.sh                # Server startup script (auto-detects RAM & JAR)
├── *.jar                   # Your Minecraft server JAR (auto-detected)
└── [server files]          # World data, configs, mods, logs, etc.
```

### Why This Structure?

The `docker/` subdirectory isolates build files from server data:
- **Faster builds**: Only Docker files sent to build context (not world data/logs)
- **Cleaner**: Separation of infrastructure vs. server data
- **Flexible**: Server files stay at root, easily accessible

## Configuration

### Ports

Default ports exposed:
- `25565` - Minecraft server
- `25575` - RCON (remote console, optional)

To change ports, edit `docker-compose.yml`:
```yaml
ports:
  - "25565:25565"  # Format: "host_port:container_port"
  - "25575:25575"
```

### Server JAR Auto-Detection

The startup script automatically finds your server JAR in this priority order:
1. `fabric-server-mc.*.jar`
2. `paper-*.jar`
3. `server.jar`
4. First `*.jar` file found

**No manual configuration needed!** Just drop your JAR in the root directory.

## JVM Optimization - Aikar's Flags

This setup uses **Aikar's flags**, the industry-standard JVM optimizations for Minecraft servers.

### Key Optimizations

- **G1GC** garbage collector for low-latency pauses (targets <200ms)
- **Adaptive G1 tuning** based on heap size:
  - ≤12GB: 30-40% new generation
  - >12GB: 40-50% new generation + larger heap regions
- **MaxTenuringThreshold=1**: Prevents short-lived objects from aging unnecessarily
- **DisableExplicitGC**: Blocks plugins from triggering full GC lag spikes
- **Optimized for Minecraft's ~800MB/s memory allocation rate**

### GC Logging

Garbage collection logs are automatically saved to `logs/gc.log` with rotation (5 files × 1MB each).

**Reference**: [PaperMC - Aikar's Flags](https://docs.papermc.io/paper/aikars-flags/)

## Docker Commands

```bash
# Start server (detached)
docker-compose up -d

# Stop server gracefully
docker-compose down

# Restart server
docker-compose restart

# View logs (follow mode)
docker-compose logs -f

# View logs (last 100 lines)
docker-compose logs --tail=100

# Access console (interactive)
docker attach minecraft-server
# Press Ctrl+P, Ctrl+Q to detach without stopping

# Rebuild after Dockerfile changes
docker-compose up -d --build

# View detected RAM allocation
docker-compose logs | grep "Detected"
```

## Technical Details

| Component | Value |
|-----------|-------|
| **Base Image** | Eclipse Temurin 21 JRE on Alpine Linux |
| **Java Distribution** | Eclipse Temurin (recommended for MC servers) |
| **User** | Non-root `minecraft` user (UID 1000) |
| **Volume Mount** | Current directory → `/server` (read/write) |
| **Auto-restart** | Enabled (unless manually stopped) |
| **Healthcheck** | TCP port 25565 check every 30s |
| **EULA** | Auto-accepted on first run |

## Advanced Configuration

### Changing Java Flags

If you need to customize JVM flags beyond Aikar's recommendations, edit `start.sh` lines 103-128.

**Warning**: Only modify if you understand JVM tuning. Aikar's flags are optimal for 99% of servers.

### Multiple Server Instances

To run multiple servers on one host:

1. Create separate directories for each server
2. Modify `container_name` and `ports` in each `docker-compose.yml`:
   ```yaml
   container_name: minecraft-server-survival
   ports:
     - "25565:25565"  # Server 1

   container_name: minecraft-server-creative
   ports:
     - "25566:25565"  # Server 2 (different host port)
   ```

### Using External Database

If using a plugin that requires a database (like CoreProtect), add a database service to `docker-compose.yml`:

```yaml
services:
  minecraft:
    # ... existing config ...
    depends_on:
      - database

  database:
    image: mariadb:latest
    environment:
      MYSQL_ROOT_PASSWORD: changeme
      MYSQL_DATABASE: minecraft
    volumes:
      - ./data/mysql:/var/lib/mysql
```

## Troubleshooting

### Server won't start

**Check logs first:**
```bash
docker-compose logs
```

**Common issues:**
- No JAR file found → Place server JAR in root directory
- Port already in use → Change port in `docker-compose.yml`
- Permission denied → Run `chmod +x start.sh`

### Out of Memory Errors

**Symptoms**: `OutOfMemoryError` in logs, server crashes

**Solutions**:
1. Check detected RAM: `docker-compose logs | grep "Detected"`
2. Increase Docker memory limits in `docker-compose.yml`
3. Ensure you're leaving 1-2GB overhead for the OS
4. For 8GB host, use: `limits: memory: 8G` (will allocate ~6GB heap)

### Performance Issues

**Check GC logs:**
```bash
cat logs/gc.log
```

**If GC pauses are >200ms:**
- Increase heap size (more RAM)
- Reduce view distance
- Use server optimization plugins (Lithium, Starlight, FerriteCore)
- Consider upgrading to 16GB+ RAM

### Permission Issues

The container runs as UID 1000. If you get permission errors:

```bash
# Fix ownership
sudo chown -R 1000:1000 .

# Or make files readable
chmod -R 755 .
```

### Cannot Connect to Server

1. **Check server is running**: `docker ps`
2. **Check port mapping**: `docker-compose logs | grep "25565"`
3. **Check firewall**: Allow port 25565 TCP
4. **Check server.properties**: `server-ip=0.0.0.0` (binds to all interfaces)

## Performance Tips

1. **Preallocate world**: Use a world pregeneration plugin to avoid generation lag
2. **Optimize view distance**: 6-8 chunks is usually sufficient
3. **Use Paper/Fabric**: Better performance than Vanilla
4. **Install optimization mods**: Lithium, Starlight, Sodium (client)
5. **Monitor with GC logs**: Check `logs/gc.log` for pause times

## Backup Strategy

Create a backup script:

```bash
#!/bin/bash
# backup.sh
docker-compose exec minecraft rcon-cli save-off
docker-compose exec minecraft rcon-cli save-all
tar -czf "backup-$(date +%Y%m%d-%H%M%S).tar.gz" world world_nether world_the_end
docker-compose exec minecraft rcon-cli save-on
```

Or use a backup plugin like [DiscordSRV Backup](https://www.spigotmc.org/resources/discordsrv.18494/).

## Updating Server

1. **Stop server**: `docker-compose down`
2. **Backup world**: `tar -czf backup.tar.gz world/`
3. **Replace JAR**: Download new server JAR
4. **Start server**: `docker-compose up -d`
5. **Check logs**: `docker-compose logs -f`

## Security Considerations

- Container runs as non-root user (UID 1000)
- Alpine Linux base for minimal attack surface
- No unnecessary packages installed
- Automatic EULA acceptance (ensure you agree to Minecraft EULA)
- Consider using a firewall (iptables/ufw) to restrict port access

## Contributing

Found an issue or have a suggestion? Please open an issue or pull request.

## License

This Docker configuration is provided as-is under the MIT License. Minecraft server software has its own licenses and EULA.

## Additional Resources

- [PaperMC Documentation](https://docs.papermc.io/)
- [Fabric Wiki](https://fabricmc.net/wiki/)
- [Minecraft Wiki - Server](https://minecraft.wiki/w/Server)
- [Aikar's Flags Explained](https://docs.papermc.io/paper/aikars-flags/)

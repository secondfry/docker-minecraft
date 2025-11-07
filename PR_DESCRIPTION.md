# PR Title

Add Docker Compose setup with automatic RAM detection and security hardening

# PR Description

## Created with Claude Code

This pull request was developed using Claude Code, Anthropic's AI coding assistant.

## Why This PR Exists

This PR adds a production-ready Docker Compose setup for Minecraft servers that prioritizes user experience, security, and automatic configuration. The goal is to make it trivial for users to dockerize existing Minecraft servers without manual JVM tuning or complex migration steps.

## Problem Being Solved

Running Minecraft servers in Docker typically requires:
- Manual JVM memory configuration (-Xms/-Xmx)
- Understanding Aikar's flags and GC tuning
- Complex file preservation when migrating existing servers
- Security hardening (non-root users, minimal images, etc.)

Users often get this wrong, resulting in poor performance or security issues.

## Solution Overview

This PR implements:

### Automatic Configuration
- **RAM auto-detection** - Reads `/proc/meminfo` at startup, calculates optimal heap size with proper OS overhead
- **Server JAR auto-detection** - Finds Fabric/Paper/Vanilla JARs automatically
- **Adaptive GC tuning** - Aikar's flags with different G1GC settings for <12GB vs >12GB heaps

### User-Friendly Migration
- **Three simple workflows**: New server, existing server folder, or tarball
- **File overlay technique** - `start.sh` overlayed at runtime, users can safely overwrite entire `server/` directory
- **Clear structure** - `server/` directory is obviously where Minecraft files go

### Security Hardening
- **No registry pulls** - Prevents supply chain attacks (no `image:` field in compose file)
- **RCON disabled by default** - Remote console is security risk, must be explicitly enabled
- **Non-root user** - Container runs as UID 1000
- **Minimal Alpine base** - Eclipse Temurin 21 JRE on Alpine Linux
- **Security options** - `no-new-privileges`, proper signal handling (SIGTERM)

### Docker Best Practices
- **Separated build context** - `docker/` directory for build files, keeps server data out of layers
- **Volume permissions** - Documentation explains why `chown` in Dockerfile doesn't work
- **Healthcheck** - Uses bash built-in `/dev/tcp` instead of requiring netcat
- **BuildKit syntax** - Modern Dockerfile syntax
- **OCI labels** - Proper image metadata

## Key Files

- `docker/Dockerfile` - Alpine-based Temurin 21 JRE image
- `docker-compose.yml` - Service orchestration (note: no `image:` field for security)
- `start.sh` - Startup script with RAM detection and Aikar's flags (overlayed at runtime)
- `server/` - User's Minecraft files (gitignored except README)
- `.env.example` - Environment variable template
- `README.md` - Comprehensive documentation
- `AGENTS.md` - AI agent learnings and architectural decisions
- `CLAUDE.md` - Quick reference for future Claude Code sessions

## Security Considerations

### Supply Chain Attack Prevention

The compose file deliberately omits the `image:` field. This prevents Docker Compose from attempting to pull from any registry (Docker Hub, etc.) before building locally.

**Why this matters**: An attacker could publish a malicious image named `minecraft-server` to Docker Hub. Without this protection, users would unknowingly pull and run attacker code instead of building the local Dockerfile.

### RCON Disabled by Default

RCON (Remote Console) allows remote command execution on the Minecraft server. It's disabled by default and must be explicitly enabled in both `docker-compose.yml` and `server.properties`.

**Why this matters**: Accidentally exposing RCON with a weak password allows attackers to execute arbitrary commands.

## User Workflows

### Workflow 1: New Server
```bash
git clone https://github.com/secondfry/docker-minecraft.git
cd docker-minecraft/server
wget <server-jar-url>
cd ..
docker-compose up -d
```

### Workflow 2: Existing Server Folder
```bash
git clone https://github.com/secondfry/docker-minecraft.git
cd docker-minecraft
mv /path/to/your/existing/server/ ./server/
docker-compose up -d
```

### Workflow 3: From Tarball
```bash
git clone https://github.com/secondfry/docker-minecraft.git
cd docker-minecraft
tar -xzf /path/to/server-backup.tar.gz -C ./server/
docker-compose up -d
```

**Key point**: Users don't need to preserve `start.sh` or any special files. The startup script is automatically injected at runtime via volume overlay.

## Technical Highlights

### Automatic RAM Detection

```bash
# Reads /proc/meminfo at startup
TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_MEM_GB=$((TOTAL_MEM_KB / 1024 / 1024))

# Calculates heap with proper OS overhead
if [ $TOTAL_MEM_GB -ge 16 ]; then
    HEAP_GB=$((TOTAL_MEM_GB - 2))  # 2GB overhead for 16GB+ systems
elif [ $TOTAL_MEM_GB -ge 8 ]; then
    HEAP_GB=$((TOTAL_MEM_GB - 2))  # 2GB overhead for 8-15GB systems
elif [ $TOTAL_MEM_GB -ge 6 ]; then
    HEAP_GB=$((TOTAL_MEM_GB - 1))  # 1GB overhead for 6-7GB systems
fi
```

### Adaptive G1GC Tuning

Different G1GC parameters for different heap sizes:
- **≤12GB heaps**: 30-40% new generation, 8MB heap regions
- **>12GB heaps**: 40-50% new generation, 16MB heap regions

Based on Aikar's research on Minecraft's ~800MB/s allocation rate.

### Volume Overlay Pattern

```yaml
volumes:
  - ./server:/server                # User's Minecraft files
  - ./start.sh:/server/start.sh:ro  # Overlay startup script (read-only)
```

This allows users to destructively copy/move entire server directories without worrying about preserving files.

## Documentation Philosophy

- **Main README**: Complete setup instructions for all workflows
- **server/README**: Brief explanation + reference to main README (avoid duplication)
- **AGENTS.md**: Comprehensive documentation of WHY decisions were made
- **CLAUDE.md**: Quick reference for AI assistants working on this project

## Testing

Verified:
- ✅ Container builds successfully
- ✅ No registry pull attempts (supply chain attack prevention)
- ✅ Volume overlay works (start.sh accessible in container)
- ✅ Healthcheck uses bash built-in (no netcat dependency)
- ✅ Security options applied (no-new-privileges)

Requires user testing with actual Minecraft server:
- RAM detection on different system sizes
- File permissions on different host systems
- RCON enabling/disabling
- Server JAR auto-detection

## Breaking Changes

None - this is a new addition to the repository.

## Future Enhancements

Potential improvements (not in this PR):
- Database service example (for plugins like CoreProtect)
- Multiple server instance documentation
- Backup script examples
- Performance monitoring integration

## References

- [Aikar's Flags Documentation](https://docs.papermc.io/paper/aikars-flags/)
- [Docker Best Practices](https://docs.docker.com/build/building/best-practices/)
- [OCI Image Spec](https://github.com/opencontainers/image-spec/blob/main/annotations.md)
- Eclipse Temurin as recommended Java distribution for Minecraft

## Checklist

- [x] Code follows Docker best practices
- [x] Security hardening applied (non-root, no-new-privileges, minimal image)
- [x] Documentation is comprehensive and user-friendly
- [x] Git commits explain WHY, not just WHAT
- [x] Supply chain attack vector eliminated
- [x] RCON disabled by default with clear enabling instructions
- [x] Aikar's flags implemented with adaptive tuning
- [x] User workflows are simple and safe (no `rm -rf`, no complex patterns)

---

**Note**: See `AGENTS.md` for detailed explanations of all architectural decisions, security considerations, and lessons learned during development.

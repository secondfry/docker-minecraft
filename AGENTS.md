# AI Agent Development Notes

This document captures key learnings and decisions made during the development of this Docker Compose setup.

## Git Commit Message Best Practices

### Focus on "Why" Not "How"

**The diff shows HOW the code changed. Commit messages should explain WHY.**

Good commit messages answer:
- **Why was this change necessary?** (The problem or motivation)
- **What problem does it solve?** (The context)
- **What are the consequences?** (Important side effects or implications)

Bad commit messages:
```
Add localhost prefix
Remove image field
Update docker-compose.yml
```

Good commit messages:
```
Security: Prevent supply chain attack via Docker Hub

Changed image name from 'minecraft-server:latest' to
'localhost/minecraft-server:latest' to prevent Docker Compose from
attempting to pull from Docker Hub before building locally.

Without this fix, an attacker could publish a malicious image named
'minecraft-server' to Docker Hub and users would unknowingly pull and
run the attacker's code instead of building the local Dockerfile.

The 'localhost/' prefix ensures Docker only uses locally built images.
```

### Commit Message Structure

```
<type>: <short summary> (50 chars or less)

<blank line>

<detailed explanation of WHY this change was made>
- What problem does it solve?
- What was wrong with the previous approach?
- What are the security/performance implications?

<blank line>

<optional: additional context, related issues, etc.>
```

## Security Learnings

### Supply Chain Attack via Docker Image Pull

**Problem**: Docker Compose tries to pull images from registries before building locally.

**Risk**: An attacker could publish a malicious image with the same name to Docker Hub. Users would unknowingly run attacker code instead of building the local Dockerfile.

**Solutions evaluated**:
1. ❌ `image: minecraft-server:latest` - Vulnerable to supply chain attack
2. ⚠️ `image: localhost/minecraft-server:latest` - Attempts localhost registry lookup
3. ✅ Omit `image:` field entirely - Zero registry lookups, most secure

**Why the final solution works**:
- Docker Compose only builds locally when only `build:` is specified
- No registry lookups (Docker Hub, localhost, etc.)
- Image auto-tagged as `<project>_<service>` (e.g., `docker-minecraft_minecraft`)
- Completely eliminates supply chain attack vector

### RCON Security

**Problem**: RCON (Remote Console) exposed by default is a security risk.

**Solution**: Disable by default, document how to enable.

**Why**: RCON allows remote command execution. If accidentally exposed with weak password, attackers can execute arbitrary commands on the Minecraft server.

## Docker Best Practices

### Volume Mounts and Permissions

**Learning**: `RUN chown` in Dockerfile has NO effect on volume mounts.

**Why**: Volume mounts happen at runtime and override image layers.

**Solutions**:
1. Match host UID to container UID (1000)
2. Fix permissions on host with `chown`
3. Run container as host user with `user: "${UID}:${GID}"`

### Healthcheck Implementation

**Initial approach**: `nc -z localhost 25565`
**Problem**: netcat not installed in Alpine image

**Solution**: `timeout 5 bash -c '</dev/tcp/localhost/25565'`
**Why**: Bash built-in `/dev/tcp` requires no additional packages

### Build Context Separation

**Structure chosen**:
```
.
├── docker/          # Build context
│   ├── Dockerfile
│   └── .dockerignore
├── server/          # Server data (not in build context)
└── secondfry-start.sh         # Overlayed at runtime
```

**Why**:
- Faster builds (only sends Docker files to build context)
- Server data stays out of Docker layers
- Clean separation: infrastructure vs application data

### File Overlay Pattern

**Problem**: Users need to migrate existing servers safely.

**Solution**: Overlay `secondfry-start.sh` at runtime via volume mount:
```yaml
volumes:
  - ./server:/server
  - ./secondfry-start.sh:/server/secondfry-start.sh:ro
```

**Why**:
- Users can destructively copy/move entire server directories
- secondfry-start.sh always up-to-date from repository
- No need to preserve files when migrating

## User Experience Learnings

### Documentation Simplicity

**Problem**: Initial commands were complex shell patterns:
```bash
shopt -s dotglob && mv /path/to/server/* ./server/
```

**User feedback**: "Stop suggesting strange copy and move patterns"

**Solution**: Straightforward commands:
```bash
mv /path/to/your/existing/server/ ./server/
cp -a /path/to/your/existing/server/. ./server/
```

**Why**: Simplicity trumps cleverness. Users prefer familiar, readable commands.

### Avoid `rm -rf` in Documentation

**Problem**: Suggesting `rm -rf ./server && mv ...` is dangerous.

**Why**: If `mv` fails, user loses the server directory. Never suggest destructive commands.

**Solution**: Only suggest non-destructive operations or clearly separate them.

### README Structure

**Initial approach**: Duplicate instructions in both `README.md` and `server/README.md`

**Problem**: Duplication causes maintenance burden and inconsistencies.

**Solution**:
- Main `README.md`: Complete setup instructions
- `server/README.md`: Brief explanation + link to main README

**Why**: Single source of truth, easier to maintain.

## Memory Management

### Automatic RAM Detection

**Approach**: Read `/proc/meminfo` to detect total RAM at container startup.

**Formula**:
```
Total RAM → Heap Size (leaving OS overhead)
6-7 GB    → Total - 1 GB
8-15 GB   → Total - 2 GB
16+ GB    → Total - 2 GB
```

**Why**:
- Users don't need to manually configure -Xms/-Xmx
- Proper overhead prevents OOM kills
- Works automatically in different environments

### Docker Memory Limits

**Decision**: Comment out by default.

**Why**:
- Dedicated servers should use all available RAM
- Auto-detection works best without artificial limits
- Only needed for multi-tenant hosts

**Important**: If limits are set, auto-detection sees ONLY the limit, not host RAM.

## Workflow Design

### User Workflows Supported

1. **New server**: Download JAR → `docker-compose up`
2. **Existing server**: `mv /path/to/server/ ./server/` → `docker-compose up`
3. **From tarball**: `tar -xzf backup.tar.gz -C ./server/` → `docker-compose up`

**Design principle**: Make it trivial to dockerize existing servers with zero file preservation needed.

## Aikar's Flags Implementation

**Key optimization**: Adaptive G1GC tuning based on heap size

```bash
if [ ${HEAP_GB:-0} -gt 12 ]; then
    G1_NEW_SIZE=40
    G1_MAX_NEW_SIZE=50
    # ... larger heap settings
else
    G1_NEW_SIZE=30
    G1_MAX_NEW_SIZE=40
    # ... smaller heap settings
fi
```

**Why**: Minecraft's memory allocation patterns differ at scale. Larger heaps benefit from different G1GC parameters.

## Architecture Decisions

### Why Eclipse Temurin on Alpine?

- **Temurin**: Industry standard, recommended for Minecraft servers
- **Alpine**: Minimal attack surface, smaller image size
- **JRE not JDK**: Server doesn't need compilation tools

### Why separate server/ directory?

**User perspective**: "Put your server here" is immediately clear.

**Technical benefits**:
- Clean separation from Docker infrastructure
- Easy to backup: `tar -czf backup.tar.gz server/`
- Easy to migrate existing servers
- Entire directory is gitignored except README

### Why overlay secondfry-start.sh?

**Problem solved**: Users accidentally overwriting startup script when migrating servers.

**Solution**: Script lives at repo root, overlayed into container at runtime.

**Benefit**: Users can destructively copy/move servers without worry.

## Common Pitfalls Avoided

### Hidden Files in Server Directory

**Problem**: `.fabric/` directory contains important state.

**Initial mistake**: `cp /path/to/server/* ./server/` misses hidden files.

**Solution**:
- For copy: `cp -a /path/to/server/. ./server/` (includes hidden)
- For move: `mv /path/to/server/ ./server/` (includes hidden)

### Docker Compose Commands

**Modern syntax**: `docker compose` (space, not hyphen)
**Legacy syntax**: `docker-compose` (may not be available)

**Documentation**: Use `docker-compose` for broader compatibility, but both work.

## Testing and Validation

**What was tested**:
- ✅ Container builds successfully
- ✅ No registry pull attempts
- ✅ Volume mounts work correctly
- ✅ secondfry-start.sh overlay works
- ✅ Healthcheck uses bash built-in (no netcat)

**What should be tested by users**:
- Actual Minecraft server startup (needs JAR file)
- RAM detection on different system sizes
- File permissions on different host systems
- RCON enabling/disabling

## Principles for AI Agents

### When Working with Users

1. **Listen to feedback**: "Stop suggesting strange patterns" → simplify immediately
2. **Security matters**: Supply chain attacks are real, not cosmetic issues
3. **Don't suggest dangerous commands**: Never `rm -rf` in user-facing docs
4. **Simplicity over cleverness**: Familiar commands > complex shell patterns
5. **Single source of truth**: Avoid duplicating documentation

### Git Commits

1. **Explain WHY, not HOW**: The diff shows how, commit explains why
2. **Include context**: What problem does this solve?
3. **Note security implications**: Make them explicit
4. **Think like a future developer**: What would you want to know?

### Documentation

1. **Concise is better**: Don't duplicate, reference
2. **User perspective first**: "Put your server here" not "Volume mount point"
3. **Progressive disclosure**: Quick start → detailed config → advanced topics
4. **Real examples**: Show actual commands, not placeholders

### Security

1. **Assume malicious actors**: Supply chain, RCON exposure, etc.
2. **Defense in depth**: Non-root user, no-new-privileges, minimal image
3. **Secure by default**: Disable risky features, document how to enable
4. **Make security violations loud**: Don't silently pull from registries

## Tools and Techniques

### Shell Best Practices

```bash
# Good: Includes hidden files
cp -a /source/. /dest/

# Good: Simple and clear
mv /source/ /dest/

# Bad: Misses hidden files
cp /source/* /dest/

# Bad: Dangerous if mv fails
rm -rf /dest && mv /source/ /dest/
```

### Docker Compose Security

```yaml
# ✅ Secure: Only builds locally
services:
  app:
    build: ./docker

# ❌ Vulnerable: Attempts registry pull first
services:
  app:
    build: ./docker
    image: my-app:latest
```

### Volume Overlay Technique

```yaml
volumes:
  - ./data:/app/data           # Main data directory
  - ./script.sh:/app/script.sh:ro  # Overlay file (read-only)
```

**Use case**: Provide scripts that users shouldn't accidentally overwrite.

## Summary

**This project demonstrates**:
- Secure Docker practices (no registry pulls, non-root user, minimal image)
- User-friendly design (trivial to migrate existing servers)
- Automatic configuration (RAM detection, JAR detection)
- Best practices (Aikar's flags, proper GC tuning)
- Clear documentation (concise, single source of truth)

**Key takeaway**: Always think about the user's workflow and security implications, not just technical correctness.

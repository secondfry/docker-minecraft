# Instructions for Claude Code

If you are working on this repository, read @AGENTS.md first. It contains critical learnings and context about:

- Git commit message best practices (focus on WHY not HOW)
- Security decisions made in this project
- Docker best practices specific to this setup
- User workflow design principles
- Common pitfalls and how they were avoided

@AGENTS.md documents the reasoning behind architectural decisions, not just what was done. Understanding the "why" will help you make consistent decisions when extending or modifying this project.

## Quick Context

This is a Docker Compose setup for Minecraft servers with:

- **Automatic RAM detection** - no manual JVM configuration needed
- **Aikar's optimized flags** - industry-standard performance tuning
- **User-friendly migration** - trivial to dockerize existing servers
- **Security-first design** - no registry pulls, non-root user, minimal attack surface

## Key Files

- `docker/Dockerfile` - Alpine-based Temurin 21 JRE image
- `docker-compose.yml` - Service orchestration (note: no `image:` field - security)
- `secondfry-start.sh` - Startup script overlayed at runtime (NOT in server/ directory)
- `server/` - User's Minecraft files go here (gitignored except README)

## Critical: Security

1. **No image: field in docker-compose.yml** - Prevents supply chain attacks (see AGENTS.md)
2. **RCON disabled by default** - Remote console is security risk
3. **Volume overlays** - Users can safely overwrite server/ without breaking secondfry-start.sh

## User Workflows

See @AGENTS.md for detailed explanations of why these workflows are designed this way.

1. New server: Download JAR to server/ → `docker-compose up`
2. Existing server: `mv /path/to/server/ ./server/` → `docker-compose up`
3. From tarball: `tar -xzf backup.tar.gz -C ./server/` → `docker-compose up`

## Documentation Philosophy

- **Main README.md**: Complete setup instructions
- **server/README.md**: Brief explanation + reference to main README
- **AGENTS.md**: AI agent context and learnings
- **CLAUDE.md**: This file (pointer to AGENTS.md)

## When Making Changes

1. Read @AGENTS.md to understand WHY things are the way they are
2. Follow git commit message best practices (explain WHY in commit body)
3. Keep user workflows simple and safe (no `rm -rf`, no complex shell patterns)
4. Think about security implications (supply chain, RCON, permissions)
5. Update AGENTS.md if you learn something new

## Example: Good vs Bad Changes

**Bad**: Add `image: minecraft-server:latest` for "convenience"
**Why bad**: Supply chain attack vector (see @AGENTS.md Security section)

**Good**: Document a new security consideration in @AGENTS.md
**Why good**: Helps future developers understand decisions

**Bad**: Suggest `rm -rf ./server && mv /old/server ./server` in docs
**Why bad**: Destructive if mv fails, dangerous for users

**Good**: Suggest `mv /path/to/server/ ./server/`
**Why good**: Simple, safe, includes hidden files

Read @AGENTS.md for full context.

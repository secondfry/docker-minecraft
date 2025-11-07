# Server Directory

This is where your Minecraft server files live.

## What Goes Here?

Place all your Minecraft server files in this directory:
- ✅ Server JAR file (Fabric, Paper, Vanilla, etc.)
- ✅ World data (`world/`, `world_nether/`, `world_the_end/`)
- ✅ Configuration files (`server.properties`, `ops.json`, etc.)
- ✅ Mods and plugins (`mods/`, `plugins/`)
- ✅ Any other server files

## Important: start.sh is Auto-Injected

The `start.sh` script is **NOT stored in this directory**. It's automatically injected at runtime by Docker from the repository root.

**This means you can safely copy/move your entire server here without worrying about overwriting anything!**

The startup script is always up-to-date from the repository and provides:
- Automatic RAM detection
- Automatic server JAR detection
- Aikar's optimized JVM flags

## Setup Instructions

See the main [README.md](../README.md) for complete setup instructions including:
- New server setup
- Migrating existing servers
- Extracting from tarballs
- Memory configuration
- File permissions

## Notes

- Everything in this directory is gitignored (except this README)
- Your server data won't be committed to version control
- The container runs as UID 1000 - see main README for permission details

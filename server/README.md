# Server Directory

This is where your Minecraft server files live.

## What Goes Here?

Place all your Minecraft server files in this directory:
- ✅ Server JAR file (Fabric, Paper, Vanilla, etc.)
- ✅ World data (`world/`, `world_nether/`, `world_the_end/`)
- ✅ Configuration files (`server.properties`, `ops.json`, etc.)
- ✅ Mods and plugins (`mods/`, `plugins/`)
- ✅ Resource packs
- ✅ Any other server files

## What's Provided?

This directory contains:
- **`start.sh`** - Startup script with automatic RAM detection and Aikar's flags
  - You can customize this if needed, but the defaults work great
  - Automatically detects your server JAR
  - Automatically configures JVM based on available RAM

## Quick Start

### Option 1: New Server

1. Download your server JAR:
   ```bash
   # Example for Fabric 1.21.8
   wget https://meta.fabricmc.net/v2/versions/loader/1.21.8/0.17.0/1.1.0/server/jar \
     -O fabric-server-mc.1.21.8-loader.0.17.0-launcher.1.1.0.jar
   ```

2. Start the server (from project root):
   ```bash
   cd ..
   docker-compose up -d
   ```

### Option 2: Existing Server

1. Copy or move your existing server files here:
   ```bash
   cp -r /path/to/old/server/* .
   # or
   mv /path/to/old/server/* .
   ```

2. Make sure `start.sh` is kept (it's provided by this repo):
   ```bash
   # If you accidentally overwrote it:
   git checkout server/start.sh
   ```

3. Start the server (from project root):
   ```bash
   cd ..
   docker-compose up -d
   ```

### Option 3: From Tarball

1. Extract your server tarball here:
   ```bash
   tar -xzf /path/to/server-backup.tar.gz -C .
   ```

2. Ensure `start.sh` exists (provided by this repo)

3. Start the server (from project root):
   ```bash
   cd ..
   docker-compose up -d
   ```

## File Permissions

The container runs as UID 1000. If you encounter permission errors, see the main [README.md](../README.md#file-permissions-and-volume-mounts) for solutions.

## Notes

- Everything in this directory (except `start.sh` and this README) is gitignored
- Your server data is safe and won't be committed to version control
- The `start.sh` script is version controlled so you get updates
- If you customize `start.sh`, you'll need to merge updates manually

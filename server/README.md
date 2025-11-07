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

**You can copy or move your entire server directory here without worrying about overwriting anything!**

## How start.sh Works

The `start.sh` script is **NOT stored in this directory**. It's automatically injected at runtime by Docker from the repository root. This means:

✅ **Safe to copy contents**: `cp -a /old/server/. .` - Includes hidden files!
✅ **Safe to move directory**: `rm -rf ../server && mv /old/server ../server` - Works perfectly!
✅ **Safe to extract tarball**: `tar -xzf backup.tar.gz -C .` - Go ahead!

The startup script will always be available and up-to-date.

## Quick Start

### Option 1: New Server

1. Download your server JAR here:
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

1. Copy your server files here (includes hidden files like .fabric/):
   ```bash
   # Copy contents including hidden files
   cp -a /path/to/old/server/. .
   ```

2. Start the server (from project root):
   ```bash
   cd ..
   docker-compose up -d
   ```

### Option 3: From Tarball

1. Extract directly here:
   ```bash
   # Move tarball to repo root, then extract
   mv /path/to/server-backup.tar.gz ../
   tar -xzf ../server-backup.tar.gz -C .
   ```

2. Start the server (from project root):
   ```bash
   cd ..
   docker-compose up -d
   ```

## What's Provided Automatically?

- **`start.sh`** - Injected at runtime (you never see it in this directory)
  - Automatic RAM detection
  - Automatic server JAR detection
  - Aikar's optimized JVM flags
  - Always up-to-date from repository

## File Permissions

The container runs as UID 1000. If you encounter permission errors, see the main [README.md](../README.md#file-permissions-and-volume-mounts) for solutions.

## Notes

- **Everything in this directory is gitignored** (except this README)
- Your server data is safe and won't be committed to version control
- You can safely overwrite everything when migrating servers
- The startup script is always provided by the repository

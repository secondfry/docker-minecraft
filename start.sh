#!/usr/bin/env bash

# Minecraft server startup script with Aikar's optimized flags
# Optimized for 6GB RAM allocation

# Accept EULA on first run if not already accepted
if [ ! -f eula.txt ]; then
    echo "eula=true" > eula.txt
fi

# Function to handle graceful shutdown
shutdown() {
    echo "Received shutdown signal, stopping server..."
    exit 0
}

# Trap SIGTERM and SIGINT for graceful shutdown
trap shutdown SIGTERM SIGINT

# Aikar's flags optimized for 6GB RAM
# See: https://docs.papermc.io/paper/aikars-flags
java \
    -Xms6G \
    -Xmx6G \
    -XX:+UseG1GC \
    -XX:+ParallelRefProcEnabled \
    -XX:MaxGCPauseMillis=200 \
    -XX:+UnlockExperimentalVMOptions \
    -XX:+DisableExplicitGC \
    -XX:+AlwaysPreTouch \
    -XX:G1NewSizePercent=30 \
    -XX:G1MaxNewSizePercent=40 \
    -XX:G1HeapRegionSize=8M \
    -XX:G1ReservePercent=20 \
    -XX:G1HeapWastePercent=5 \
    -XX:G1MixedGCCountTarget=4 \
    -XX:InitiatingHeapOccupancyPercent=15 \
    -XX:G1MixedGCLiveThresholdPercent=90 \
    -XX:G1RSetUpdatingPauseTimePercent=5 \
    -XX:SurvivorRatio=32 \
    -XX:+PerfDisableSharedMem \
    -XX:MaxTenuringThreshold=1 \
    -Dusing.aikars.flags=https://mcflags.emc.gs \
    -Daikars.new.flags=true \
    -jar fabric-server-mc.1.21.8-loader.0.17.0-launcher.1.1.0.jar \
    nogui

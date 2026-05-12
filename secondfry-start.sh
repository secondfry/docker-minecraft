#!/usr/bin/env bash

# Minecraft server startup script with Aikar's optimized flags
# Automatically detects available RAM and configures JVM accordingly
# Reference: https://docs.papermc.io/paper/aikars-flags

set -e

echo "=========================================="
echo "Using secondfry-start.sh startup script"
echo "This is NOT part of the original server distribution"
echo "=========================================="
echo ""

# Check if server has its own start.sh and warn user
if [ -f /server/start.sh ] && [ "$(realpath /server/start.sh)" != "$(realpath "$0")" ]; then
    echo "⚠️  WARNING: Your server directory contains its own start.sh file"
    echo "⚠️  We are using secondfry-start.sh instead of your server's start.sh"
    echo "⚠️  If you want to use the original start.sh, please modify docker-compose.yml"
    echo ""
fi

# Accept EULA on first run if not already accepted
if [ ! -f eula.txt ]; then
    echo "eula=true" > eula.txt
fi

# Function to handle graceful shutdown
shutdown() {
    echo "Received shutdown signal, stopping server gracefully..."
    exit 0
}

# Trap SIGTERM and SIGINT for graceful shutdown
trap shutdown SIGTERM SIGINT

# ===== Automatic RAM Detection =====

# Aikar recommends 6-10GB for most servers, rarely beneficial above 12GB
# Reference: https://docs.papermc.io/paper/aikars-flags
MAX_HEAP_GB=${MAX_MEMORY_GB:-12}

# Allow manual override via environment variable
if [ -n "$MEMORY_GB" ]; then
    HEAP_GB=$MEMORY_GB
    echo "Using manually configured memory: ${HEAP_GB}GB"
    HEAP_SIZE="${HEAP_GB}G"
else
    # Detect total available memory
    TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_MEM_MB=$((TOTAL_MEM_KB / 1024))
    TOTAL_MEM_GB=$((TOTAL_MEM_MB / 1024))

    echo "Detected ${TOTAL_MEM_GB}GB total system memory (${TOTAL_MEM_MB}MB)"

    # Calculate heap size (leave overhead for OS to prevent OOM errors)
    if [ $TOTAL_MEM_GB -lt 6 ]; then
        echo "WARNING: Only ${TOTAL_MEM_GB}GB RAM detected. Aikar recommends minimum 6GB."
        echo "Allocating ${TOTAL_MEM_GB}GB to heap (risky - may cause OOM)"
        HEAP_GB=$TOTAL_MEM_GB
    elif [ $TOTAL_MEM_GB -lt 8 ]; then
        # For 6-7GB, leave 1GB overhead
        HEAP_GB=$((TOTAL_MEM_GB - 1))
    else
        # For 8GB+, leave 2GB overhead
        HEAP_GB=$((TOTAL_MEM_GB - 2))
    fi

    # Apply upper limit to prevent GC performance issues
    # Aikar: "more memory does not mean better performance above a certain point"
    if [ $HEAP_GB -gt $MAX_HEAP_GB ]; then
        echo "Capping heap at ${MAX_HEAP_GB}GB (Aikar recommends 6-10GB, rarely beneficial above 12GB)"
        echo "Override with MAX_MEMORY_GB environment variable if needed for heavy modpacks"
        HEAP_GB=$MAX_HEAP_GB
    fi

    HEAP_SIZE="${HEAP_GB}G"
    echo "Allocating ${HEAP_SIZE} to Java heap (leaving overhead for OS)"
fi

# ===== GC Mode Selection =====
#
# GC_MODE=aikar       (default) Aikar's G1GC flags. Safe for vanilla/Paper.
# GC_MODE=shenandoah  Generational Shenandoah. Recommended for Folia on
#                     hosts with ≥16 logical cores AND ≥16GB heap; on
#                     smaller hosts it is marginal vs G1GC (barrier
#                     overhead can exceed the pause-time savings).
#
# ConcGCThreads auto-scales at ~1 per 8 logical cores (Folia's region
# scheduler reserves ~80% of cores for tick threads; GC counts against
# that budget). ParallelGCThreads is left at the JVM default — it only
# runs during STW and does not compete with ticking.

GC_MODE=${GC_MODE:-aikar}

# Detect logical CPU count for Shenandoah tuning
CPU_COUNT=$(nproc 2>/dev/null || echo 1)

# ===== G1GC Configuration Based on Heap Size =====
# Only relevant when GC_MODE=aikar; Shenandoah ignores these.

if [ "$GC_MODE" = "aikar" ]; then
    # For >12GB, use adjusted G1 settings per Aikar's recommendations
    if [ ${HEAP_GB:-0} -gt 12 ]; then
        echo "Using G1GC settings optimized for >12GB heap"
        G1_NEW_SIZE=40
        G1_MAX_NEW_SIZE=50
        G1_HEAP_REGION_SIZE=16M
        G1_RESERVE_PERCENT=15
        G1_INIT_HEAP_OCCUPANCY=20
    else
        echo "Using standard G1GC settings for ≤12GB heap"
        G1_NEW_SIZE=30
        G1_MAX_NEW_SIZE=40
        G1_HEAP_REGION_SIZE=8M
        G1_RESERVE_PERCENT=20
        G1_INIT_HEAP_OCCUPANCY=15
    fi
fi

# ===== Find Server JAR =====

# Auto-detect server JAR (prioritize fabric, then folia, then paper, then any jar)
if [ -f fabric-server-mc.*.jar ]; then
    SERVER_JAR=$(ls -1 fabric-server-mc.*.jar | head -n1)
elif ls folia-*.jar >/dev/null 2>&1; then
    SERVER_JAR=$(ls -1 folia-*.jar | head -n1)
elif [ -f paper-*.jar ]; then
    SERVER_JAR=$(ls -1 paper-*.jar | head -n1)
elif [ -f server.jar ]; then
    SERVER_JAR="server.jar"
else
    SERVER_JAR=$(ls -1 *.jar 2>/dev/null | head -n1)
fi

if [ -z "$SERVER_JAR" ]; then
    echo "ERROR: No server JAR file found!"
    echo "Please place your Minecraft server JAR in this directory."
    exit 1
fi

echo "Using server JAR: ${SERVER_JAR}"

# ===== Start Server =====

mkdir -p logs

case "$GC_MODE" in
    shenandoah)
        # Generational Shenandoah for Folia. Pause-time GC that does not
        # compete heavily with Folia's region tick threads.
        #
        # Viability threshold: ≥16 logical cores AND ≥16GB heap. Below
        # that the read/write barriers cost more than the pause savings,
        # so Shenandoah ends up marginal (or worse) vs G1GC. We surface
        # this once at startup and let the operator decide.
        if [ "$CPU_COUNT" -lt 16 ] || [ "${HEAP_GB:-0}" -lt 16 ]; then
            echo "NOTE: Shenandoah on this host (${CPU_COUNT} cores, ${HEAP_GB}GB heap) is"
            echo "      marginal vs G1GC — barrier overhead may exceed pause savings."
            echo "      Only stay on shenandoah if /spark health shows p99 region MSPT"
            echo "      regressions on G1GC that you can't fix with chunk pregen."
        fi

        # ConcGCThreads ~ 1 per 8 logical cores, minimum 1.
        # Counts against Folia's ~80% tick-thread budget.
        CONC_GC_THREADS=$(( CPU_COUNT / 8 ))
        [ "$CONC_GC_THREADS" -lt 1 ] && CONC_GC_THREADS=1

        # Larger heaps get more GC log rotation headroom.
        if [ "${HEAP_GB:-0}" -ge 16 ]; then
            GC_LOG_FILECOUNT=10
        else
            GC_LOG_FILECOUNT=5
        fi

        echo "Starting Minecraft server with generational Shenandoah (GC_MODE=${GC_MODE})..."
        echo "Heap: ${HEAP_SIZE} | CPUs: ${CPU_COUNT} | ConcGCThreads: ${CONC_GC_THREADS}"
        echo "NOTE: Heuristic flags are intentionally omitted under ShenandoahGCMode=generational"
        echo "      (auto-tuned; manual values produce warnings)."
        echo "NOTE: For Folia, leave paper-global.yml threaded-regions/chunk-system at"
        echo "      defaults unless /spark health justifies tuning. See AGENTS.md."

        exec java \
            -Xms${HEAP_SIZE} \
            -Xmx${HEAP_SIZE} \
            -XX:+UnlockExperimentalVMOptions \
            -XX:+AlwaysPreTouch \
            -XX:+DisableExplicitGC \
            -XX:+ParallelRefProcEnabled \
            -XX:+UseShenandoahGC \
            -XX:ShenandoahGCMode=generational \
            -XX:ConcGCThreads=${CONC_GC_THREADS} \
            -Xlog:gc*:file=logs/gc.log:time,level,tags:filecount=${GC_LOG_FILECOUNT},filesize=4M \
            -jar "${SERVER_JAR}" \
            nogui
        ;;

    aikar|"")
        echo "Starting Minecraft server with Aikar's optimized flags (GC_MODE=aikar)..."
        echo "Heap: ${HEAP_SIZE} | G1NewSize: ${G1_NEW_SIZE}-${G1_MAX_NEW_SIZE}%"

        exec java \
            -Xms${HEAP_SIZE} \
            -Xmx${HEAP_SIZE} \
            -XX:+UseG1GC \
            -XX:+ParallelRefProcEnabled \
            -XX:MaxGCPauseMillis=200 \
            -XX:+UnlockExperimentalVMOptions \
            -XX:+DisableExplicitGC \
            -XX:+AlwaysPreTouch \
            -XX:G1NewSizePercent=${G1_NEW_SIZE} \
            -XX:G1MaxNewSizePercent=${G1_MAX_NEW_SIZE} \
            -XX:G1HeapRegionSize=${G1_HEAP_REGION_SIZE} \
            -XX:G1ReservePercent=${G1_RESERVE_PERCENT} \
            -XX:G1HeapWastePercent=5 \
            -XX:G1MixedGCCountTarget=4 \
            -XX:InitiatingHeapOccupancyPercent=${G1_INIT_HEAP_OCCUPANCY} \
            -XX:G1MixedGCLiveThresholdPercent=90 \
            -XX:G1RSetUpdatingPauseTimePercent=5 \
            -XX:SurvivorRatio=32 \
            -XX:+PerfDisableSharedMem \
            -XX:MaxTenuringThreshold=1 \
            -Dusing.aikars.flags=https://mcflags.emc.gs \
            -Daikars.new.flags=true \
            -Xlog:gc*:logs/gc.log:time,uptime:filecount=5,filesize=1M \
            -jar "${SERVER_JAR}" \
            nogui
        ;;

    *)
        echo "ERROR: Unknown GC_MODE='${GC_MODE}'."
        echo "Valid values: aikar (default), shenandoah"
        exit 1
        ;;
esac

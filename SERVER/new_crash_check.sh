#!/bin/zsh

# --------------------------------------------------------------------------------
# Description:  Automation of installing and managing Minecraft Servers
# Usage:        crontab -e paste: * * * * * /home/Minecraft/SERVER/monitor-crash.sh
# Created by:   Kaiman
# Since:        21/08/2024 (DD/MM/YYYY)
# --------------------------------------------------------------------------------
# Version:      3.0
# Last Updated: 14/04/2026 (DD/MM/YYYY)
# --------------------------------------------------------------------------------

# CRON-MONITOR.sh - Runs every minute: ONLY crash detection + auto-restart

# Global Variables (same as original)
CURRENT_DATE=$(date '+%Y-%m-%d')
BASE_DIR="/home/Minecraft/SERVER"
LOGS_DIR="$BASE_DIR/logs"
LOG_FILE="$LOGS_DIR/latest.log"
PROPERTIES_FILE="$BASE_DIR/env/server-properties.env"
LATEST_CLI="$BASE_DIR/output/.latest-cli-output.txt"
ACTUAL_CLI="$BASE_DIR/output/.actual-cli-output.txt"

# Logging (unchanged, but only for crashes)
log() {
    local MESSAGE="$1"
    local STATE_CHANGE="$2"
    local TIMESTAMP_MIN=$(date '+%Y-%m-%d %H:%M')
    local TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    if [[ "$STATE_CHANGE" != "CHANGE" && "$MESSAGE" != ERROR* ]]; then
        return 0
    fi

    mkdir -p "$LOGS_DIR"
    local STRIPPED_MESSAGE=$(echo -e "$MESSAGE" | sed -r "s/\x1B\[[0-9;]*[mK]//g")

    # Daily log rotation (unchanged)
    if [[ -f "$LOG_FILE" ]]; then
        LOGGED_DAY=$(sed -n '2p' "$LOG_FILE" | cut -d' ' -f2 2>/dev/null || echo "$CURRENT_DATE")
        if [[ "$LOGGED_DAY" != "$CURRENT_DATE" ]]; then
            mv "$LOG_FILE" "$LOGS_DIR/${LOGGED_DAY}.log"
        fi
    fi

    if [[ ! -f "$LOG_FILE" ]]; then
        touch "$LOG_FILE"
    fi

    echo -e "$MESSAGE"
    echo "[CRON-MONITOR $TIMESTAMP]: $STRIPPED_MESSAGE" >> "$LOG_FILE"
}

# Load env (minimal)
loadEnvConfig() {
    if [[ -f "$PROPERTIES_FILE" ]]; then
        source "$PROPERTIES_FILE"
    fi
}

# Simplified restart (no web notify, no status change)
restartServer() {
    loadEnvConfig
    local START_SCRIPT="$SERVER_PATH/start-server.sh"

    if [[ -z "$SERVER_NAME" || -z "$SERVER_PATH" || ! -x "$START_SCRIPT" ]]; then
        log "ERROR: Invalid config or start script missing" "CHANGE"
        exit 1
    fi

    # Kill and restart tmux
    tmux kill-session -t "$SERVER_NAME" 2>/dev/null
    zsh "$START_SCRIPT"
    sleep 2

    if tmux has-session -t "$SERVER_NAME" 2>/dev/null; then
        log "CRASH: Auto-restarted $SERVER_NAME" "CHANGE"
    else
        log "ERROR: Restart failed for $SERVER_NAME" "CHANGE"
    fi
}

# Main crash check (unchanged logic)
checkIfServerCrashed() {
    loadEnvConfig
    
    if ! tmux has-session -t "$SERVER_NAME" 2>/dev/null; then
        log "CRASH: No tmux session. Restarting $SERVER_NAME..." "CHANGE"
        restartServer
        return
    fi

    mkdir -p "$BASE_DIR/output"
    tmux send-keys -t "$SERVER_NAME" "/list" C-m
    sleep 1
    tail -n 32 "$SERVER_PATH/logs/latest.log" > "$ACTUAL_CLI"

    if [[ ! -f "$LATEST_CLI" ]]; then
        cp "$ACTUAL_CLI" "$LATEST_CLI"
        return
    fi

    if cmp -s "$ACTUAL_CLI" "$LATEST_CLI"; then
        log "CRASH: CLI frozen. Restarting $SERVER_NAME..." "CHANGE"
        restartServer
    else
        cp "$ACTUAL_CLI" "$LATEST_CLI"
    fi
}

# Run only if ONLINE
loadEnvConfig
[[ "$SERVER_STATUS" == "ONLINE" ]] && checkIfServerCrashed

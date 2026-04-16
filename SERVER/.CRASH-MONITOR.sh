#!/bin/zsh

# --------------------------------------------------------------------------------
# Description:  Crash monitor for Minecraft server (manual output + cron logging)
# Usage:        Paste: ( crontab -l 2>/dev/null; echo '* * * * * /home/Minecraft/SERVER/.CRASH-MONITOR.sh' ) | crontab -
# Created by:   Kaiman
# Since:        21/08/2024 (DD/MM/YYYY)
# --------------------------------------------------------------------------------
# Version:      3.2
# Last Updated: 15/04/2026 (DD/MM/YYYY)
# --------------------------------------------------------------------------------

CURRENT_DATE=$(date '+%Y-%m-%d')
BASE_DIR="/home/Minecraft/SERVER"
LOGS_DIR="$BASE_DIR/logs"
LOG_FILE="$LOGS_DIR/latest.log"
PROPERTIES_FILE="$BASE_DIR/env/server-properties.env"
LATEST_CLI="$BASE_DIR/output/.latest-cli-output.txt"
ACTUAL_CLI="$BASE_DIR/output/.actual-cli-output.txt"

IS_INTERACTIVE=0
[[ -t 1 ]] && IS_INTERACTIVE=1

log() {
    local MESSAGE="$1"
    local LEVEL="$2"
    local TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    local STRIPPED_MESSAGE

    STRIPPED_MESSAGE=$(echo -e "$MESSAGE" | sed -r 's/\x1B\[[0-9;]*[mK]//g')

    # Przy ręcznym uruchomieniu pokazuj wszystko w terminalu
    if (( IS_INTERACTIVE )); then
        echo -e "$MESSAGE"
    fi

    # Do loga z crona zapisuj tylko ważne rzeczy
    if [[ "$LEVEL" != "CHANGE" && "$MESSAGE" != ERROR* ]]; then
        return 0
    fi

    mkdir -p "$LOGS_DIR"

    # Rotacja dzienna
    if [[ -f "$LOG_FILE" ]]; then
        local LOGGED_DAY
        LOGGED_DAY=$(sed -n '2p' "$LOG_FILE" | cut -d' ' -f2 2>/dev/null)
        [[ -z "$LOGGED_DAY" ]] && LOGGED_DAY="$CURRENT_DATE"

        if [[ "$LOGGED_DAY" != "$CURRENT_DATE" ]]; then
            mv "$LOG_FILE" "$LOGS_DIR/${LOGGED_DAY}.log"
        fi
    fi

    [[ -f "$LOG_FILE" ]] || touch "$LOG_FILE"

    echo "[CRON-MONITOR $TIMESTAMP]: $STRIPPED_MESSAGE" >> "$LOG_FILE"
}

loadEnvConfig() {
    if [[ -f "$PROPERTIES_FILE" ]]; then
        source "$PROPERTIES_FILE"
    else
        echo -e "ERROR: Missing env file: $PROPERTIES_FILE"
        exit 1
    fi
}

restartServer() {
    local START_SCRIPT="$SERVER_PATH/start-server.sh"

    if [[ -z "$SERVER_NAME" || -z "$SERVER_PATH" ]]; then
        log "ERROR: Missing SERVER_NAME or SERVER_PATH in env" "CHANGE"
        exit 1
    fi

    if [[ ! -x "$START_SCRIPT" ]]; then
        log "ERROR: Start script missing or not executable: $START_SCRIPT" "CHANGE"
        exit 1
    fi

    log "SERVER: Restarting $SERVER_NAME..." "INFO"

    tmux kill-session -t "$SERVER_NAME" 2>/dev/null
    zsh "$START_SCRIPT"
    sleep 2

    if tmux has-session -t "$SERVER_NAME" 2>/dev/null; then
        log "CRASH: Auto-restarted $SERVER_NAME" "CHANGE"
    else
        log "ERROR: Restart failed for $SERVER_NAME" "CHANGE"
        exit 1
    fi
}

checkIfServerCrashed() {
    if [[ -z "$SERVER_NAME" || -z "$SERVER_PATH" ]]; then
        log "ERROR: SERVER_NAME or SERVER_PATH is empty" "CHANGE"
        exit 1
    fi

    if ! tmux has-session -t "$SERVER_NAME" 2>/dev/null; then
        log "CRASH: No tmux session. Restarting $SERVER_NAME..." "CHANGE"
        restartServer
        return
    fi

    mkdir -p "$BASE_DIR/output"

    if [[ ! -f "$SERVER_PATH/logs/latest.log" ]]; then
        log "ERROR: Missing server log file: $SERVER_PATH/logs/latest.log" "CHANGE"
        return
    fi

    log "SERVER: Checking $SERVER_NAME..." "INFO"

    tmux send-keys -t "$SERVER_NAME" "/list" C-m
    sleep 1
    tail -n 32 "$SERVER_PATH/logs/latest.log" > "$ACTUAL_CLI"

    if [[ ! -f "$LATEST_CLI" ]]; then
        log "SERVER: No previous CLI snapshot. Creating baseline." "INFO"
        cp "$ACTUAL_CLI" "$LATEST_CLI"
        return
    fi

    if cmp -s "$ACTUAL_CLI" "$LATEST_CLI"; then
        log "CRASH: CLI frozen. Restarting $SERVER_NAME..." "CHANGE"
        restartServer
    else
        log "SERVER: CLI changed. Server is healthy." "INFO"
        cp "$ACTUAL_CLI" "$LATEST_CLI"
    fi
}

main() {
    loadEnvConfig

    if [[ "$SERVER_STATUS" == "ONLINE" ]]; then
        checkIfServerCrashed
    else
        log "SERVER: $SERVER_NAME status is $SERVER_STATUS, skipping crash check." "INFO"
    fi
}

main
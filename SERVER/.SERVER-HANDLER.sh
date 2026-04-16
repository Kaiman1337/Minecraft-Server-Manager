#!/bin/zsh

# --------------------------------------------------------------------------------
# Description:  Minecraft Server Handler Script
# Usage:        crontab -e (* * * * * /home/Minecraft/SERVER/.SERVER-HANDLER.sh)
# Created by:   Kaiman
# Since:        21/08/2024 (DD/MM/YYYY)
# --------------------------------------------------------------------------------
# Version:      3.0
# --------------------------------------------------------------------------------

# Global Variables
LOGGED_DATE=""
CURRENT_DATE=$(date '+%Y-%m-%d')
LOGGED_DAY=""
BASE_DIR="/home/Minecraft/SERVER"
LOGS_DIR="$BASE_DIR/logs"
LOG_FILE="$LOGS_DIR/latest.log"
PROPERTIES_FILE="$BASE_DIR/env/server-properties.env"
LATEST_CLI="$BASE_DIR/output/.latest-cli-output.txt"
ACTUAL_CLI="$BASE_DIR/output/.actual-cli-output.txt"

# ----------------------------------------------------------
# Logging Function
# ----------------------------------------------------------
log() {
    local MESSAGE="$1"
    local TIMESTAMP_MIN=$(date '+%Y-%m-%d %H:%M')
    local TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    # Ensure log directory exists
    mkdir -p "$LOGS_DIR"

    # Extract plain message (strip ANSI color codes for logging)
    local STRIPPED_MESSAGE=$(echo -e "$MESSAGE" | sed -r "s/\x1B\[[0-9;]*[mK]//g")

    # Handle daily log rotation
    if [[ -f "$LOG_FILE" ]]; then
        if [[ -z "$LOGGED_DAY" ]]; then
            LOGGED_DAY=$(sed -n '2p' "$LOG_FILE" | cut -d' ' -f2)
        fi
        [[ -z "$LOGGED_DAY" ]] && LOGGED_DAY="$CURRENT_DATE"

        if [[ "$LOGGED_DAY" != "$CURRENT_DATE" ]]; then
            local ARCHIVED_LOG_FILE="$LOGS_DIR/${LOGGED_DAY}.log"
            mv "$LOG_FILE" "$ARCHIVED_LOG_FILE"
            LOGGED_DAY="$CURRENT_DATE"
            echo "[SERVER-HANDLER]: Log archived as $ARCHIVED_LOG_FILE"
        fi
    fi

    # Add header for new minute in log
    if [[ -z "$LOGGED_DATE" || "$LOGGED_DATE" != "$TIMESTAMP_MIN" ]]; then
        LOGGED_DATE="$TIMESTAMP_MIN"
        echo -e "\n[SERVER-HANDLER $TIMESTAMP]\n-----------------------------------------------------------------------------------------------" >> "$LOG_FILE"
    fi

    # Log to file (cleaned) and print to console (with color if present)
    echo -e "$MESSAGE"
    echo "[SERVER-HANDLER]: $STRIPPED_MESSAGE" >> "$LOG_FILE"
}

# ----------------------------------------------------------
# ENV: Load values from *.env file
# ----------------------------------------------------------
loadEnvConfig() {
    local PROPERTIES_FILE="$1"
    # Load environment variables from the .env file
    # Ensure the file exists and then source it
    if [ -f $PROPERTIES_FILE ]; then
        source $PROPERTIES_FILE
    else
        echo "Error: .env file not found!"
        exit 1
    fi
    
    SERVER_STATUS=$SERVER_STATUS
    SERVER_TYPE=$SERVER_TYPE
    SERVER_NAME=$SERVER_NAME
    SERVER_DIR=$SERVER_PATH
    SERVER_ID=$SERVER_ID
}

# ----------------------------------------------------------
# Restart Minecraft Server
# ----------------------------------------------------------
restartServer() {
    loadEnvConfig $PROPERTIES_FILE
    local START_SCRIPT="$SERVER_DIR/start-server.sh"

    # Basic validations
    if [[ -z "$SERVER_NAME" || -z "$SERVER_DIR" ]]; then
        log "ERROR: Missing server name or directory."
        exit 1
    fi
    if [[ ! -x "$START_SCRIPT" ]]; then
        log "ERROR: '$START_SCRIPT' not found or not executable."
        exit 1
    fi

    # Kill existing session
    if tmux has-session -t "$SERVER_NAME" 2>/dev/null; then
        log "SERVER: Killing existing tmux session [$SERVER_NAME]."
        tmux kill-session -t "$SERVER_NAME"
    else
        log "SERVER: No existing tmux session [$SERVER_NAME]."
    fi

    # Start new session
    log "SERVER: Starting new tmux session [$SERVER_NAME]."
    zsh "$START_SCRIPT"
    sleep 1

    # Verify session
    if tmux has-session -t "$SERVER_NAME" 2>/dev/null; then
        log "SERVER: Successfully restarted server - type: $SERVER_TYPE >> name: $SERVER_NAME."
    else
        log "ERROR: Failed to start [$SERVER_NAME]."
        exit 1
    fi
}

# ----------------------------------------------------------
# Check if the server has crashed
# ----------------------------------------------------------
checkIfServerCrashed() {
    loadEnvConfig $PROPERTIES_FILE
    
    # Check if the server is running in tmux
    if ! tmux has-session -t "$SERVER_NAME" 2>/dev/null; then
        log "SERVER: No tmux session for [$SERVER_NAME]. Restarting..."
        restartServer
        return
    fi
    
    # Ensure latest log exists
    local latest_log=$LOG_FILE
    if [[ ! -f "$latest_log" ]]; then
        log "ERROR: Log file [$latest_log] not found!"
        return
    fi
    
    # Force output to log via /list command
    tmux send-keys -t "$SERVER_NAME" "/list" C-m
    sleep 1
    
    # Generate actual CLI snapshot
    tail -n 32 "$SERVER_DIR/logs/latest.log" > "$ACTUAL_CLI"

    # First run: create baseline if missing
    if [[ ! -f "$LATEST_CLI" ]]; then
        log "WARNING: No previous CLI snapshot. Creating baseline."
        cp "$ACTUAL_CLI" "$LATEST_CLI"
        return
    fi
    
    # Compare logs: if identical, assume crash
    if cmp -s "$ACTUAL_CLI" "$LATEST_CLI"; then
        log "SERVER: CLI output unchanged. Assuming crash. Restarting..."
        restartServer
    else
        log "SERVER: CLI output changed. Server appears healthy."
        cp "$ACTUAL_CLI" "$LATEST_CLI"
    fi
    
    # Log active tmux sessions
    local sessions=$(tmux list-sessions | sed 's/^/\t        - /; s/windows/window/')
    log "ACTIVE SESSIONS:\n$sessions"
}

# ----------------------------------------------------------
# Set Server Online
# ----------------------------------------------------------
setServerOnline() {
    loadEnvConfig $PROPERTIES_FILE

    log "Starting server - type: $SERVER_TYPE >> name: $SERVER_NAME..."
    
    # Restart the server
    restartServer
    
    # Notify remote server via HTTP
    if ! wget -q -O - "http://localhost/SERVER/changeServerStatus.php?server_status=ONLINE&server_id=$SERVER_ID"; then
        log "WARNING: Failed to notify server status change to ONLINE for ID $SERVER_ID"
    fi

    # Update .env status locally
    if grep -q '^SERVER_STATUS=' "$PROPERTIES_FILE"; then
        sed -i 's/^SERVER_STATUS=.*/SERVER_STATUS=ONLINE/' "$PROPERTIES_FILE"
    else
        echo "SERVER_STATUS=ONLINE" >> "$PROPERTIES_FILE"
    fi

    # Save the latest server log output
    if [[ -f "$SERVER_DIR/logs/latest.log" ]]; then
        tail -n 50 "$SERVER_DIR/logs/latest.log" > "$LATEST_CLI"
    else
        log "WARNING: Server log not found at $SERVER_DIR/logs/latest.log"
    fi
    
    log "Started server - type: $SERVER_TYPE >> name: $SERVER_NAME."
}

# ----------------------------------------------------------
# Set Server Offline
# ----------------------------------------------------------
setServerOffline() {
    loadEnvConfig "$PROPERTIES_FILE"
    log "Stopping server - type: $SERVER_TYPE >> name: $SERVER_NAME..."

    # Kill the tmux session
    if tmux has-session -t "$SERVER_NAME" 2>/dev/null; then
        tmux kill-session -t "$SERVER_NAME"
        log "Tmux session for $SERVER_NAME killed."
    else
        log "No tmux session found for $SERVER_NAME."
    fi

    # Notify remote server
    if ! wget -q -O - "http://localhost/SERVER/changeServerStatus.php?server_status=OFFLINE&server_id=$SERVER_ID"; then
        log "WARNING: Failed to notify server status change to OFFLINE for ID $SERVER_ID"
    fi

    # Update local .env file
    if grep -q '^SERVER_STATUS=' "$PROPERTIES_FILE"; then
        sed -i 's/^SERVER_STATUS=.*/SERVER_STATUS=OFFLINE/' "$PROPERTIES_FILE"
    else
        echo "SERVER_STATUS=OFFLINE" >> "$PROPERTIES_FILE"
    fi

    log "Server stopped - type: $SERVER_TYPE >> name: $SERVER_NAME."
}

# ----------------------------------------------------------
# Main: Handle server based on status
# ----------------------------------------------------------
checkServerStatus() {
    if [[ -f "$PROPERTIES_FILE" ]]; then
        loadEnvConfig "$PROPERTIES_FILE"

        log "Checking server status: $SERVER_NAME (status: $SERVER_STATUS)"

        case "$SERVER_STATUS" in
            OFFLINE)
                log "SERVER: $SERVER_NAME is currently OFFLINE."
                ;;
            ONLINE)
                log "SERVER: $SERVER_NAME is ONLINE. Performing crash check..."
                checkIfServerCrashed
                ;;
            START)
                log "SERVER: $SERVER_NAME marked for START. Starting..."
                setServerOnline
                ;;
            STOP)
                log "SERVER: $SERVER_NAME marked for STOP. Stopping..."
                setServerOffline
                ;;
            *)
                log "ERROR: Invalid SERVER_STATUS '$SERVER_STATUS' in $PROPERTIES_FILE for $SERVER_NAME."
                ;;
        esac
    fi 
}

# Execute main check
checkServerStatus
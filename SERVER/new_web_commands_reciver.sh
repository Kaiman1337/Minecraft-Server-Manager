#!/bin/zsh
# WEB-COMMANDS.sh - Instant start/stop/restart from website
# Instant execution (no cron delay)
# $action = $_POST['action'];  // 'start', 'stop', or 'restart'
# exec("/home/Minecraft/SERVER/web-commands.sh $action", $output);
# echo $output[0];  // "STARTED", "STOPPED", etc.

BASE_DIR="/home/Minecraft/SERVER"
PROPERTIES_FILE="$BASE_DIR/env/server-properties.env"

# Logging (minimal for web calls)
log() {
    echo "[WEB-CMD $(date '+%Y-%m-%d %H:%M:%S')]: $1"
    echo "[WEB-CMD $(date)]: $1" >> "$BASE_DIR/web-commands.log"
}

loadEnvConfig() {
    if [[ -f "$PROPERTIES_FILE" ]]; then
        source "$PROPERTIES_FILE"
    else
        log "ERROR: $PROPERTIES_FILE not found"
        exit 1
    fi
}

# START command
doStart() {
    loadEnvConfig
    log "START command: $SERVER_NAME"
    
    if tmux has-session -t "$SERVER_NAME" 2>/dev/null; then
        log "Already running"
        echo "ALREADY_RUNNING"
        return
    fi

    zsh "$SERVER_PATH/start-server.sh"
    sleep 2
    
    if tmux has-session -t "$SERVER_NAME" 2>/dev/null; then
        sed -i 's/^SERVER_STATUS=.*/SERVER_STATUS=ONLINE/' "$PROPERTIES_FILE"
        wget -q -O - "http://localhost/SERVER/changeServerStatus.php?server_status=ONLINE&server_id=$SERVER_ID" 2>/dev/null
        log "Started successfully"
        echo "STARTED"
    else
        log "Start failed"
        echo "FAILED"
    fi
}

# STOP command
doStop() {
    loadEnvConfig
    log "STOP command: $SERVER_NAME"
    
    if tmux has-session -t "$SERVER_NAME" 2>/dev/null; then
        tmux send-keys -t "$SERVER_NAME" "stop" C-m
        sleep 5
        tmux kill-session -t "$SERVER_NAME" 2>/dev/null
    fi
    
    sed -i 's/^SERVER_STATUS=.*/SERVER_STATUS=OFFLINE/' "$PROPERTIES_FILE"
    wget -q -O - "http://localhost/SERVER/changeServerStatus.php?server_status=OFFLINE&server_id=$SERVER_ID" 2>/dev/null
    log "Stopped successfully"
    echo "STOPPED"
}

# RESTART command
doRestart() {
    loadEnvConfig
    log "RESTART command: $SERVER_NAME"
    
    if tmux has-session -t "$SERVER_NAME" 2>/dev/null; then
        tmux kill-session -t "$SERVER_NAME"
        sleep 2
    fi
    
    zsh "$SERVER_PATH/start-server.sh"
    sleep 3
    
    if tmux has-session -t "$SERVER_NAME" 2>/dev/null; then
        sed -i 's/^SERVER_STATUS=.*/SERVER_STATUS=ONLINE/' "$PROPERTIES_FILE"
        wget -q -O - "http://localhost/SERVER/changeServerStatus.php?server_status=ONLINE&server_id=$SERVER_ID" 2>/dev/null
        log "Restarted successfully"
        echo "RESTARTED"
    else
        log "Restart failed"
        echo "FAILED"
    fi
}

# Handle command from website (passed as $1)
case "${1:-}" in
    "start")
        doStart ;;
    "stop")
        doStop ;;
    "restart")
        doRestart ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1 ;;
esac

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
            echo "[SERVER-MANAGER]: Log archived as $ARCHIVED_LOG_FILE"
        fi
    fi

    # Add header for new minute in log
    if [[ -z "$LOGGED_DATE" || "$LOGGED_DATE" != "$TIMESTAMP_MIN" ]]; then
        LOGGED_DATE="$TIMESTAMP_MIN"
        echo -e "\n[SERVER-MANAGER $TIMESTAMP]\n-----------------------------------------------------------------------------------------------" >> "$LOG_FILE"
    fi

    # Log to file (cleaned) and print to console (with color if present)
    if [[ ! "$MESSAGE" == *"Entered"* ]]; then
        echo -e "$MESSAGE"
    fi
    echo "[SERVER-MANAGER]: $STRIPPED_MESSAGE" >> "$LOG_FILE"
}
deleteServer() {
    SERVER_TYPE=$1
    SERVER_NAME=$2
    SERVER_PATH="$BASE_SERVERS_DIR"
    SERVER_DIR="$SERVER_PATH/$SERVER_TYPE"

    # Check if directory is empty or has no matching subfolders/files
    if [[ -z ${(f)"$(ls -1 "$SERVER_DIR" 2>/dev/null)"} ]]; then
        echo -e "\n\e[1;31m[CONSOLE: SERVERS] No server folders found in $SERVER_DIR/*"
        echo -ne "\n\e[1;37mPress 'ENTER' return to menu..."
        read PRESSED_KEY
        chooseServerType DELETE
    fi

    local options=()
    SERVER_LIST=($(basename -a "$SERVER_DIR"/*))
    for entry in "${SERVER_LIST[@]}"; do
        options+=("${entry:t}")
    done

    if [[ -z $SERVER_NAME ]]; then
        while true; do
            clear
            center_text "[SELECT SERVER TO DELETE]"
            echo ""
            for ((i = 1; i <= ${#options[@]}; i++)); do
                printf "\e[1;32m[%d]\e[1;33m %s\n" "$i" "${options[i]}"
            done
            echo -e "\e[1;31m[Q] QUIT"
            echo -ne "\n\e[1;33m[CONSOLE: SERVERS] Select server type [press key 1–${#options[@]} or Q to quit]:\e[37m "
            read -rk1 PRESSED_KEY

            case "$PRESSED_KEY" in
                [qQ])
                    clear
                    chooseServerType DELETE
                    ;;
                [1-9] | [0-9])
                    if ((PRESSED_KEY >= 1 && PRESSED_KEY <= ${#options[@]})); then
                        local SERVER_NAME="${options[PRESSED_KEY]%}"
                        echo -e "\n\e[1;33m[CONSOLE: SERVERS] Choosen: \e[37m$SERVER_NAME\n"
                        filename="$SERVER_DIR/$SERVER_NAME"
                        break
                    else
                        echo -ne "\n\e[1;33m[CONSOLE: SERVERS] \e[31mInvalid number. \nPress 'ENTER' to try again."
                        read PRESSED_KEY
                    fi
                    ;;
                *)
                    echo -ne "\n\e[1;33m[CONSOLE: SERVERS] \e[31mInvalid option '$PRESSED_KEY'. \nPress 'ENTER' to try again."
                    read PRESSED_KEY
                    ;;
            esac
        done
    fi

    clear
    center_text "[SERVER - $SERVER_NAME | $(date '+[DATE: %y/%m/%d | TIME: %H:%M:%S]')]"

    log "\e[1;30m[CONSOLE: SERVERS] Ensuring server \e[34m$SERVER_NAME\e[30m is \e[31mOFFLINE\e[30m..."
    if tmux has-session -t "$SERVER_NAME" 2>/dev/null; then
        log "\e[1;30m[CONSOLE: SERVERS] Ensuring no-one is on server $SERVER_NAME..."

        # Send /list to the server
        tmux send-keys -t "$SERVER_NAME" "/list" C-m
        sleep 1  # Allow time for the command to output
        # Capture latest pane output
        OUTPUT=$(tmux capture-pane -pt "$SERVER_NAME" -S -100 | tail -n 20)
        # Get the last line with player info
        LIST_LINE=$(echo "$OUTPUT" | grep -i "players online" | tail -n 1)

        log "\e[1;30m[CONSOLE: SERVERS] /list output: $LIST_LINE"
        if echo "$LIST_LINE" | grep -iqE "\b0\b.*players? online"; then
            log "\e[1;30m[CONSOLE: SERVERS] No players online."

            if [[ -f "$BASE_DIR/env/server-properties-$SERVER_NAME.env" ]]; then
                sed -i 's/^server-port=.*/server-port=25565/' "$SERVER_DIR/$SERVER_NAME/server.properties"
                DEST="$BASE_DIR/env/server-properties-$SERVER_NAME.env"
            else
                DEST="$BASE_DIR/env/server-properties.env"
            fi

            log "\e[1;30m[CONSOLE: SERVERS] Stopping server: $SERVER_NAME..."
            log "\e[1;30m[CONSOLE: SERVERS] Sending STOP command to server $SERVER_NAME..."
            log "\e[1;30m[CONSOLE: SERVERS] Server $SERVER_NAME: Shutting down..."
            tmux send-keys -t "$SERVER_NAME" "stop" C-m
            sleep 6
            log "\e[1;30m[CONSOLE: SERVERS] Server $SERVER_NAME stopped..."

            loadEnvConfig $DEST
            log "\e[1;30m[CONSOLE: SERVERS] Setting server $SERVER_NAME state to \e[31mOFFLINE\e[30m..."
            curl -s --insecure "$WEB_URL/php/changeServerStatus.php?server_status=OFFLINE&server_id=$SERVER_ID"

            if rm "$DEST"; then
                log "\e[1;30m[CONSOLE: SERVERS] Successfully deleted: $DEST"
            else
                log "\e[1;31m[CONSOLE: SERVERS] ERROR: Failed to delete: $DEST"
            fi
            sleep 2
            if tmux has-session -t "$SERVER_NAME" 2>/dev/null; then
                log "\e[1;31m[CONSOLE: SERVERS] ERROR: Failed to shutdown server $SERVER_NAME."
                exit 1
            else
                log "\e[1;30m[CONSOLE: SERVERS] Server $SERVER_NAME is \e[31mOFFLINE\e[33m."
            fi
        else
            log "\e[1;31m[CONSOLE: SERVERS] Players are still online! Canceling server deletion."
            exit 1
        fi
    else
        log "\e[1;30m[CONSOLE: SERVERS] Server $SERVER_NAME is already \e[31mOFFLINE\e[30m.."
    fi

    SERVER_FILE="$SERVER_DIR/$SERVER_NAME"
    if [[ -d "$SERVER_FILE" ]]; then
        log "\e[1;30m[CONSOLE: SERVERS] Deleting server: $SERVER_NAME..."
        while IFS= read -r line; do
            log "\e[0;30m[CONSOLE:  DELETE] $line"
        done < <(rm -rv "$SERVER_FILE")
        if [[ ! -d "$SERVER_FILE" ]]; then
            log "\e[1;30m[CONSOLE: SERVERS] Server $SERVER_NAME deleted successfully."
            removeServerFromDatabase "" "$SERVER_NAME"
        else
            log "\e[1;31m[CONSOLE: SERVERS] Failed to delete server: $SERVER_NAME."
        fi
    else
        log "\e[1;31m[CONSOLE: SERVERS] Server $SERVER_FILE not found."
    fi

    # End prompt
    echo -ne "\n\e[1;37mPress 'ENTER' to continue..."
    read PRESSED_KEY
}
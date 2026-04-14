stopStartRestartServer() {
    ACTION=$1
    SERVER_TYPE=$2
    SERVER_NAME=$3
    SERVER_PATH="$BASE_SERVERS_DIR"
    SERVER_DIR="$SERVER_PATH/$SERVER_TYPE"

    # Check if directory is empty or has no matching subfolders/files
    if [[ -z ${(f)"$(ls -1 "$SERVER_DIR" 2>/dev/null)"} ]]; then
        echo -e "\n\e[1;31m[CONSOLE: SERVERS] No server folders found in $SERVER_DIR/*"
        echo -ne "\n\e[1;37mPress 'ENTER' return to menu..."
        read PRESSED_KEY
        chooseServerType $ACTION
    fi

    local options=()
    SERVER_LIST=($(basename -a "$SERVER_DIR"/*))
    for entry in "${SERVER_LIST[@]}"; do
        options+=("${entry:t}")
    done

    if [[ -z $SERVER_NAME ]]; then
        while true; do
            clear
            if [[ "$ACTION" == "STOP" ]]; then
                center_text "[SELECT SERVER TO STOP]"
            elif [[ "$ACTION" == "START" ]]; then
                center_text "[SELECT SERVER TO START]"
            elif [[ "$ACTION" == "RESTART" ]]; then
                center_text "[SELECT SERVER TO RESTART]"
            fi

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
                    chooseServerType $ACTION
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
    center_text "[SERVER - \e[34m$SERVER_NAME\e[33m | `date "+DATE: %y/%m/%d | TIME: %H:%M:%S"`]"
    if [[ "$ACTION" == "RESTART" ]]; then
        log "\e[1;30m[CONSOLE: SERVERS] Sending RESTART command to server \e[34m$SERVER_NAME\e[30m..."
        if [[ -f "$BASE_DIR/env/server-properties-$SERVER_NAME.env" ]]; then
            sed -i 's/^server-port=.*/server-port=25565/' "$SERVER_DIR/$SERVER_NAME/server.properties"
            DEST="$BASE_DIR/env/server-properties-$SERVER_NAME.env"
        else
            DEST="$BASE_DIR/env/server-properties.env"
        fi
        loadEnvConfig $DEST
        # Changing *.env SERVER_STATUS=RESTART
        sed -i 's/^SERVER_STATUS=.*/SERVER_STATUS=RESTART/' "$DEST"
        # Sending 'stop' command to server
        log "\e[1;30m[CONSOLE: SERVERS] Sending STOP command to server $SERVER_NAME..."
        log "\e[1;30m[CONSOLE: SERVERS] Server $SERVER_NAME: Shutting down..."
        if tmux send-keys -t "$SERVER_NAME" "stop" C-m; then
            sleep 5
        else
            log "\e[1;31m[CONSOLE: SERVERS] Server $SERVER_NAME session don't exist - server was already down."
        fi
        # Killing server session
        log "\e[1;30m[CONSOLE: SERVERS] Server $SERVER_NAME stopped..."
        # Setting server status to OFFLINE
        log "\e[1;30m[CONSOLE: SERVERS] Setting server \e[34m$SERVER_NAME\e[30m state to \e[31mOFFLINE\e[30m..."
        sleep 1
        # Checking is server session was killed
        if tmux has-session -t "$SERVER_NAME" 2>/dev/null; then
            log "\e[1;31m[CONSOLE: SERVERS] ERROR: Failed to shutdown server $SERVER_NAME."
        else
            log "\e[1;30m[CONSOLE: SERVERS] Server \e[34m$SERVER_NAME\e[30m is \e[31mOFFLINE\e[30m."
        fi

        # Starting server
        log "\e[1;30m[CONSOLE: SERVERS] Setting up server \e[34m$SERVER_NAME\e[30m..."
        SOURCE="$BASE_SERVERS_DIR/$SERVER_TYPE/$SERVER_NAME/server-properties.env"
        if [[ -n "$(tmux ls 2> /dev/null)" ]]; then
            SERVER_PROPERTIES="$SERVER_DIR/$SERVER_NAME/server.properties"
            if grep -q "^server-port=" "$SERVER_PROPERTIES"; then
                sed -i 's/^server-port=.*/server-port=25566/' "$SERVER_PROPERTIES"
            else
                echo "server-port=25566" >> "$SERVER_PROPERTIES"
            fi
            log "\e[1;30m[CONSOLE: SERVERS] Changing \e[31mserver-port\e[34m=\e[32m25566\e[30m in: $SERVER_PROPERTIES"
            DEST="/home/Minecraft/SERVER/env/server-properties-$SERVER_NAME.env"
        else
            DEST="/home/Minecraft/SERVER/env/server-properties.env"
        fi
        # Checking if *.env file exists in server folder
        if [ ! -f "$SOURCE" ]; then
            log "\e[1;31m[CONSOLE: SERVERS] ERROR: $SOURCE does not exist."
            exit 1
        fi
        # Copying *.env file from server folder to */SERVER/env/
        cat "$SOURCE" > "$DEST"
        log "\e[1;30m[CONSOLE: SERVERS] Copying $SOURCE to $DEST."
        if [[ ! -f $DEST ]]; then
            log "\e[1;31m[CONSOLE: SERVERS] ERROR: Failed to copy $SOURCE to $DEST."
            exit 1
        fi
        log "\e[1;30m[CONSOLE: SERVERS] SUCCESS: Server $SERVER_NAME config file copied."
        
        # Load *.env file values
        loadEnvConfig $DEST
        if [[ -z "$SERVER_NAME" ]]; then
            log "\e[1;31m[CONSOLE: SERVERS] ENV: ERROR: Server name not found in $DEST."
            exit 1
        fi

        # Changing server state to ONLINE
        log "\e[1;30m[CONSOLE: SERVERS] Sending START command to server $SERVER_NAME..."
        # Starting server
        if [[ ! -x "$SERVER_DIR/start-server.sh" ]]; then
            log "\e[1;31m[CONSOLE: SERVERS] ERROR: $SERVER_DIR/start-server.sh not found or not executable."
            exit 1
        fi
        log "\e[1;30m[CONSOLE: SERVERS] Starting server $SERVER_NAME..."
        zsh "$SERVER_DIR/start-server.sh"

        if ! tmux has-session -t "${SERVER_NAME//./_}" 2> /dev/null; then
            log "\e[1;31m[CONSOLE: SERVERS] ERROR: Failed to start server $SERVER_NAME."
            exit 1
        fi
        sed -i 's/^SERVER_STATUS=.*/SERVER_STATUS=ONLINE/' "$DEST"
        log "\e[1;30m[CONSOLE: SERVERS] Server \e[34m$SERVER_NAME\e[30m is \e[32mONLINE\e[30m!"
        log "\e[1;30m[CONSOLE: SERVERS] Server \e[34m$SERVER_NAME\e[30m Succesfully restarted!"
    else
        if tmux has-session -t "${SERVER_NAME//./_}" 2> /dev/null; then
            if [[ "$ACTION" == "STOP" ]]; then
                if [[ -f "$BASE_DIR/env/server-properties-$SERVER_NAME.env" ]]; then
                    sed -i 's/^server-port=.*/server-port=25565/' "$SERVER_DIR/$SERVER_NAME/server.properties"
                    DEST="$BASE_DIR/env/server-properties-$SERVER_NAME.env"
                else
                    DEST="$BASE_DIR/env/server-properties.env"
                fi
                loadEnvConfig $DEST
                # Changing *.env SERVER_STATUS=STOP
                log "\e[1;30m[CONSOLE: SERVERS] Sending STOP command to server \e[34m$SERVER_NAME\e[30m..."
                sed -i 's/^SERVER_STATUS=.*/SERVER_STATUS=STOP/' "$DEST"
                # Sending 'stop' command to server
                log "\e[1;30m[CONSOLE: SERVERS] Server $SERVER_NAME: Shutting down..."
                if tmux send-keys -t "$SERVER_NAME" "stop" C-m; then
                    sleep 5
                else
                    log "\e[1;31m[CONSOLE: SERVERS] Server $SERVER_NAME session don't exist - server was already down."
                fi
                # Killing server session
                log "\e[1;30m[CONSOLE: SERVERS] Server $SERVER_NAME stopped..."
                # Setting server status to OFFLINE
                log "\e[1;30m[CONSOLE: SERVERS] Setting server \e[34m$SERVER_NAME\e[30m state to \e[31mOFFLINE\e[30m..."
                curl -s --insecure "$WEB_URL/php/changeServerStatus.php?server_status=OFFLINE&server_id=$SERVER_ID"
                if rm "$DEST"; then
                    log "\e[1;30m[CONSOLE: SERVERS] Succesfully deleted: $DEST"
                else
                    log "\e[1;31m[CONSOLE: SERVERS] ERROR: Failed to delete: $DEST"
                fi
                sleep 1
                # Checking is server session was killed
                if tmux has-session -t "$SERVER_NAME" 2>/dev/null; then
                    log "\e[1;31m[CONSOLE: SERVERS] ERROR: Failed to shutdown server $SERVER_NAME."
                else
                    log "\e[1;30m[CONSOLE: SERVERS] Server \e[34m$SERVER_NAME\e[30m is \e[31mOFFLINE\e[30m."
                fi
                echo -e "\e[1;37m====================================================================================="
            elif [[ "$ACTION" == "START" ]]; then
                ACTIVE_SESSIONS=$(tmux list-sessions | awk '{ printf "\033[1;31m\t- %s\033[0m\n", $0 }')
                echo -e "\e[1;30m[CONSOLE: SERVERS] Server is already \e[32mONLINE\e[30m: \n$ACTIVE_SESSIONS"
                echo -e "\e[1;37m====================================================================================="
            fi
        else
            if [[ "$ACTION" == "STOP" ]]; then
                ACTIVE_SESSIONS=$(tmux list-sessions | awk '{ printf "\033[1;31m\t- %s\033[0m\n", $0 }')
                echo -e "\e[1;30m[CONSOLE: SERVERS] Server is already \e[31mOFFLINE\e[30m: \n$ACTIVE_SESSIONS"
                echo -e "\e[1;37m====================================================================================="
            elif [[ "$ACTION" == "START" ]]; then
                log "\e[1;30m[CONSOLE: SERVERS] Setting up server \e[34m$SERVER_NAME\e[30m..."

                SOURCE="$BASE_SERVERS_DIR/$SERVER_TYPE/$SERVER_NAME/server-properties.env"
                if [[ -n "$(tmux ls 2> /dev/null)" ]]; then
                    SERVER_PROPERTIES="$SERVER_DIR/$SERVER_NAME/server.properties"
                    if grep -q "^server-port=" "$SERVER_PROPERTIES"; then
                        sed -i 's/^server-port=.*/server-port=25566/' "$SERVER_PROPERTIES"
                    else
                        echo "server-port=25566" >> "$SERVER_PROPERTIES"
                    fi
                    log "\e[1;30m[CONSOLE: SERVERS] Changing \e[31mserver-port\e[34m=\e[32m25566\e[30m in: $SERVER_PROPERTIES"
                    DEST="$BASE_DIR/env/server-properties-$SERVER_NAME.env"
                else
                    DEST="$BASE_DIR/env/server-properties.env"
                fi

                # Copying *.env file from server folder to */SERVER/env/
                mkdir -p "$BASE_DIR/env"
                cat "$SOURCE" > "$DEST"
                log "\e[1;30m[CONSOLE: SERVERS] Copying $SOURCE to $DEST."
                if [[ ! -f $DEST ]]; then
                    log "\e[1;31m[CONSOLE: SERVERS] ERROR: Failed to copy $SOURCE to $DEST."
                    exit 1
                fi
                log "\e[1;30m[CONSOLE: SERVERS] SUCCESS: Server $SERVER_NAME config file copied."
                
                # Load *.env file values
                loadEnvConfig $DEST
                if [[ -z "$SERVER_NAME" ]]; then
                    log "\e[1;31m[CONSOLE: SERVERS] ENV: ERROR: Server name not found in $DEST."
                    exit 1
                fi

                # Changing server state to ONLINE
                curl -s --insecure "$WEB_URL/php/changeServerStatus.php?server_status=ONLINE&server_id=$SERVER_ID"
                log "\e[1;30m[CONSOLE: SERVERS] Sending START command to server $SERVER_NAME..."

                # Starting server
                if [[ ! -x "$SERVER_DIR/start-server.sh" ]]; then
                    log "\e[1;31m[CONSOLE: SERVERS] ERROR: $SERVER_DIR/start-server.sh not found or not executable."
                    exit 1
                fi
                log "\e[1;30m[CONSOLE: SERVERS] Starting server $SERVER_NAME..."
                zsh "$SERVER_DIR/start-server.sh"

                if ! tmux has-session -t "${SERVER_NAME//./_}" 2> /dev/null; then
                    log "\e[1;31m[CONSOLE: SERVERS] ERROR: Failed to start server $SERVER_NAME."
                    exit 1
                fi
                sed -i 's/^SERVER_STATUS=.*/SERVER_STATUS=ONLINE/' "$DEST"
                log "\e[1;30m[CONSOLE: SERVERS] Server $SERVER_NAME is \e[32mONLINE\e[30m!"
            fi
        fi
    fi
    # End prompt
    echo -ne "\n\e[1;37mPress 'ENTER' to continue..."
    read PRESSED_KEY
}

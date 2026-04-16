archiveServer() {
    SERVER_TYPE=$1
    SERVER_NAME=$2
    SERVER_PATH="$BASE_SERVERS_DIR"
    SERVER_DIR="$SERVER_PATH/$SERVER_TYPE"

    # Check if directory is empty or has no matching subfolders/files
    if [[ -z ${(f)"$(ls -1 "$SERVER_DIR" 2>/dev/null)"} ]]; then
        echo -e "\n\e[1;31m[CONSOLE: SERVERS] No server folders found in $SERVER_DIR/*"
        echo -ne "\n\e[1;37mPress 'ENTER' return to menu..."
        read PRESSED_KEY
        chooseServerType ARCHIVE
    fi

    local options=()
    SERVER_LIST=($(basename -a "$SERVER_DIR"/*))
    for entry in "${SERVER_LIST[@]}"; do
        options+=("${entry:t}")
    done

        if [[ -z $SERVER_NAME ]]; then
        while true; do
            clear
            center_text "[SELECT SERVER TO ARCHIVE]"
            echo ""
            for ((i = 1; i <= ${#options[@]}; i++)); do
                printf "\e[1;32m[%d]\e[1;33m %s\n" "$i" "${options[i]}"
            done
            echo -e "\e[1;31m[Q] QUIT"
            echo -ne "\n\e[1;33m[CONSOLE: SERVERS] Select servers to archive [e.g. 5 | 40 23 15 | 4-13 | 1 3 7-12]: \e[37m"
            read -r PRESSED_KEY

            case "$PRESSED_KEY" in
                [qQ])
                    clear
                    chooseServerType DELETE
                    return
                    ;;
            esac

            local token start end n
            local -a selections unique_choices selected_names
            selections=()
            selected_names=()

            for token in ${(s: :)PRESSED_KEY}; do
                if [[ "$token" =~ '^[0-9]+$' ]]; then
                    if (( token >= 1 && token <= ${#options[@]} )); then
                        selections+=("$token")
                    else
                        echo -ne "\n\e[1;33m[CONSOLE: SERVERS] \e[31mInvalid number: $token\n\e[1;37mPress 'ENTER' to try again..."
                        read
                        selections=()
                        break
                    fi

                elif [[ "$token" =~ '^[0-9]+-[0-9]+$' ]]; then
                    start=${token%-*}
                    end=${token#*-}

                    if (( start > end )); then
                        local tmp="$start"
                        start="$end"
                        end="$tmp"
                    fi

                    if (( start >= 1 && end <= ${#options[@]} )); then
                        for ((n = start; n <= end; n++)); do
                            selections+=("$n")
                        done
                    else
                        echo -ne "\n\e[1;33m[CONSOLE: SERVERS] \e[31mInvalid range: $token\n\e[1;37mPress 'ENTER' to try again..."
                        read
                        selections=()
                        break
                    fi

                else
                    echo -ne "\n\e[1;33m[CONSOLE: SERVERS] \e[31mInvalid input: $token\n\e[1;37mPress 'ENTER' to try again..."
                    read
                    selections=()
                    break
                fi
            done

            if (( ${#selections[@]} == 0 )); then
                continue
            fi

            unique_choices=(${(un)selections})

            echo -e "\n\e[1;33m[CONSOLE: SERVERS] Selected servers:\e[37m"
            for n in "${unique_choices[@]}"; do
                selected_names+=("${options[n]}")
                echo -e "\e[1;32m[$n]\e[37m ${options[n]}"
            done

            echo -ne "\n\e[1;31m[CONSOLE: SERVERS] Confirm delete selected servers? [Y/N]: \e[37m"
            read -r CONFIRM_DELETE

            if [[ "$CONFIRM_DELETE" == [Yy] ]]; then
                for SERVER_NAME in "${selected_names[@]}"; do
                    deleteServer "$SERVER_TYPE" "$SERVER_NAME"
                done
                return
            fi
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
                log "\e[1;30m[CONSOLE: SERVERS] Successfully archived: $DEST"
            else
                log "\e[1;31m[CONSOLE: SERVERS] ERROR: Failed to archive: $DEST"
            fi
            sleep 2
            if tmux has-session -t "$SERVER_NAME" 2>/dev/null; then
                log "\e[1;31m[CONSOLE: SERVERS] ERROR: Failed to shutdown server $SERVER_NAME."
                exit 1
            else
                log "\e[1;30m[CONSOLE: SERVERS] Server $SERVER_NAME is \e[31mOFFLINE\e[33m."
            fi
        else
            log "\e[1;31m[CONSOLE: SERVERS] Players are still online! Canceling server archiving."
            exit 1
        fi
    else
        log "\e[1;30m[CONSOLE: SERVERS] Server $SERVER_NAME is already \e[31mOFFLINE\e[30m.."
    fi

    SERVER_FILE="$SERVER_DIR/$SERVER_NAME"
    ARCHIVE_DIR="$BASE_ARCHIVES_DIR/$SERVER_TYPE/"
    ARCHIVE_FILE="${ARCHIVE_DIR}/${SERVER_NAME}_$(date +%Y-%m-%d_%H-%M-%S).tar.gz"
    if [[ -d "$SERVER_FILE" ]]; then
        mkdir -p "$ARCHIVE_DIR"
        log "\e[1;30m[CONSOLE: SERVERS] Archiving server: $SERVER_NAME..."
        
        if tar -czvf "$ARCHIVE_FILE" -C "$(dirname "$SERVER_FILE")" "$(basename "$SERVER_FILE")" | while IFS= read -r line; do
            log "\e[0;30m[CONSOLE:  ARCHIVE] $line"
        done; then
            log "\e[1;30m[CONSOLE: SERVERS] Server $SERVER_NAME archived successfully to $ARCHIVE_FILE."
            if rm -rf "$SERVER_FILE"; then
                log "\e[1;30m[CONSOLE: SERVERS] Server $SERVER_NAME deleted after archiving."
            else
                log "\e[1;31m[CONSOLE: SERVERS] Failed to delete server directory after archiving."
            fi
        else
            log "\e[1;31m[CONSOLE: SERVERS] Failed to archive server: $SERVER_NAME."
        fi
    else
        log "\e[1;31m[CONSOLE: SERVERS] Server directory $SERVER_FILE not found."
    fi

    if [[ ! -d "$SERVER_FILE" ]]; then
        removeServerFromDatabase "" "$SERVER_NAME"
    fi

    # End prompt
    echo -ne "\n\e[1;37mPress 'ENTER' to continue..."
    read PRESSED_KEY
}
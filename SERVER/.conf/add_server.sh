addServer() {
    SERVER_PATH="$BASE_SERVERS_DIR"
    local entries=()

    if [[ ! -d "$SERVER_PATH" ]]; then
        echo -e "\e[1;33m[CONSOLE: SERVERS] First run: creating base server directory $SERVER_PATH\e[0m"
        mkdir -p "$SERVER_PATH"
        echo -e "\e[1;32m[CONSOLE: SERVERS] Created $SERVER_PATH\e[0m"
    fi

    # Load server directories
    for entry in "$SERVER_PATH"/*; do
        [[ -d "$entry" ]] && entries+=("${entry:t}")
    done

    if ((${#entries[@]} == 0)); then
        echo -e "\e[1;33m[CONSOLE: SERVERS] First run: no server type folders found in $SERVER_PATH.\e[0m"
        echo -e "\e[1;33m[CONSOLE: SERVERS] Creating default server type folders: VANILLA, FORGE, MAP\e[0m"
        mkdir -p "$SERVER_PATH"/VANILLA "$SERVER_PATH"/FORGE "$SERVER_PATH"/MAP
        entries=(VANILLA FORGE MAP)
    fi

    while true; do
        clear
        center_text "[ADD SERVER]"
        echo ""
        for ((i = 1; i <= ${#entries[@]}; i++)); do
            printf "\e[1;32m[%d]\e[1;33m %s SERVER\n" "$i" "${entries[i]}"
        done
        echo -e "\e[1;31m[Q] QUIT"
        echo -ne "\n\e[1;33m> Select server type [press key 1–${#entries[@]} or Q to quit]:\e[37m "
        read -rk1 PRESSED_KEY
        echo ""

        case "$PRESSED_KEY" in
            [qQ])
                clear
                main
                ;;
            [1-9] | [0-9])
                if ((PRESSED_KEY >= 1 && PRESSED_KEY <= ${#entries[@]})); then
                    clear
                    local SERVER_TYPE="${entries[PRESSED_KEY]}"
                    serverMenu "$SERVER_TYPE" "$SERVER_PATH/$SERVER_TYPE"
                    break
                else
                    echo -ne "\n\e[1;31mInvalid number. Press 'ENTER' to try again.\e[0m"
                    read PRESSED_KEY
                fi
                ;;
            *)
                echo -ne "\n\e[1;31mInvalid option '$PRESSED_KEY'. Press 'ENTER' to try again.\e[0m"
                read PRESSED_KEY
                ;;
        esac
    done
}
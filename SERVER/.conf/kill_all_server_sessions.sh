# ----------------------------------------------------------
# Kill active server sessions
# ----------------------------------------------------------
killServerSessions() {
    while true; do
        clear
        center_text "[KILL SERVER SESSIONS] $(date '+[DATE: %y/%m/%d | TIME: %H:%M:%S]')"

        # Check if there are any tmux sessions
        if tmux list-sessions &>/dev/null; then
            ACTIVE_SESSIONS=$(tmux list-sessions | awk '{ printf "\033[1;31m\t- %s\033[0m\n", $0 }')
            echo -e "\n\e[1;33m[CONSOLE: SERVERS] Active servers: \n$ACTIVE_SESSIONS"
        else
            echo -e "\n\e[1;33m[CONSOLE: SERVERS] \e[31mNo active servers found."
            echo -ne "\e[1;37m\nPress 'ENTER' to return...\e[0m"
            read PRESSED_KEY
            return
        fi

        # Options
        echo -e "\n\e[1;32m[1] \e[33mKill all servers"
        echo -e "\e[1;32m[2] \e[33mKill selected server(s)"
        echo -e "\e[1;31m[Q] QUIT"
        echo -ne "\n\e[1;33mEnter choice [press key 1-2] or Q to quit: \e[37m"
        read -rk1 ACTION
        echo ""

        case "$ACTION" in
            [qQ])
                clear
                return
                ;;
            1)
                echo -ne "\n\e[1;33m[CONSOLE: SERVERS] Proceed with killing ALL servers? \e[31m[Y/N]\e[37m: "
                read -rk1 CONFIRM
                if [[ "$CONFIRM" == [Yy] ]]; then
                    tmux list-sessions | awk -F: '{print $1}' | while read -r session; do
                        tmux kill-session -t "$session"
                    done
                    zsh "/var/www/html/SERVER/stop-server.sh"
                    center_text "[ALL SERVERS KILLED]"
                else
                    echo -e "\e[1;33m[CONSOLE: SERVERS] \e[31mAction cancelled"
                fi
                ;;
            2)
                echo -e "\n\e[1;33m[CONSOLE: SERVERS] Enter server names to kill (space-separated): \e[37m"
                read -r SESSIONS_TO_KILL
                SESSIONS_TO_KILL_ARRAY=("${(@s: :)SESSIONS_TO_KILL}") # split on spaces
                for session in "${SESSIONS_TO_KILL_ARRAY[@]}"; do
                    if tmux has-session -t "$session" 2> /dev/null; then
                        tmux kill-session -t "$session"
                        echo -e "\e[1;33m[CONSOLE: SERVERS] \e[32mKilled server: $session"
                    else
                        echo -e "\e[1;33m[CONSOLE: SERVERS] \e[31mServer not found: $session"
                    fi
                done
                ;;
            *)
                echo -ne "\n\e[1;31mInvalid option '$ACTION'. \nPress 'ENTER' to try again.\e[0m"
                read PRESSED_KEY
                killServerSessions
                ;;
        esac

        echo -e "\e[1;33m[CONSOLE: SERVERS] Remaining servers: \e[31m"
        # Check if there are any tmux sessions
        if tmux list-sessions &>/dev/null; then
            ACTIVE_SESSIONS=$(tmux list-sessions | awk '{ printf "\033[1;31m\t- %s\033[37m\n", $0 }')
            echo -e "$ACTIVE_SESSIONS"
        else
            echo -e "\e[1;33m[CONSOLE: SERVERS] \e[31mNo active servers found.\e[37m"
        fi
        # End prompt
        echo -ne "\e[1;37m\nPress 'ENTER' to continue...\e[0m"
        read PRESSED_KEY
    done
}
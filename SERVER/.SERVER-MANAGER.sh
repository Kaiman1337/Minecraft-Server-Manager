#!/bin/zsh

setopt nullglob  # Allow globs to expand to nothing if no matches

# --------------------------------------------------------------------------------
# Description:  Automation of installing and managing Minecraft Servers
# Usage:        zsh .SERVER-MANAGER.sh
# Created by:   Kaiman
# Since:        21/08/2024 (DD/MM/YYYY)
# --------------------------------------------------------------------------------
# Version:      3.2
# Last Updated: 14/04/2026 (DD/MM/YYYY)
# --------------------------------------------------------------------------------

BASE_DIR="/home/Minecraft/SERVER"
ABS_PATH="$BASE_DIR/.conf"
BASE_SERVERS_DIR="/home/Minecraft/SERVERS"
DB_DIR="$BASE_DIR/db"
DB_FILE="$DB_DIR/database.sql"
WEB_ROOT="/var/www/html/SERVER"
WEB_URL="https://localhost/SERVER"

loadCore() {
    if [[ -n "$CORE_LOADED" ]]; then return 0; fi
    source "$ABS_PATH/config.sh"
    source "$ABS_PATH/load_env.sh"
    source "$ABS_PATH/log.sh"
    source "$ABS_PATH/configure_server.sh"
    ensureDatabaseFile
    CORE_LOADED=1
}

ensureDatabaseFile() {
    mkdir -p "$DB_DIR"
    if [[ ! -f "$DB_FILE" ]]; then
        cat > "$DB_FILE" <<'EOF'
--
-- Database file created by SERVER-MANAGER.sh
-- Import this file into phpMyAdmin or your MySQL server to populate the `servers` table.
--

START TRANSACTION;
-- Uncomment the following line to commit the database changes after import
-- COMMIT;

CREATE TABLE IF NOT EXISTS `servers` (
  `SERVER_ID` mediumint NOT NULL,
  `SERVER_TYPE` tinytext CHARACTER SET utf16 COLLATE utf16_polish_ci NOT NULL,
  `SERVER_NAME` tinytext CHARACTER SET utf16 COLLATE utf16_polish_ci NOT NULL,
  `SERVER_VERSION` tinytext CHARACTER SET utf16 COLLATE utf16_polish_ci NOT NULL,
  `SERVER_JAVA_VERSION` tinyint NOT NULL,
  `SERVER_PATH` tinytext CHARACTER SET utf16 COLLATE utf16_polish_ci NOT NULL,
  `SERVER_LOADER` tinytext CHARACTER SET utf16 COLLATE utf16_polish_ci,
  `SERVER_LOADER_VERSION` tinytext CHARACTER SET utf16 COLLATE utf16_polish_ci,
  `SERVER_MODS_AMOUNT` smallint DEFAULT NULL,
  `SERVER_PACKAGE_SIZE` smallint DEFAULT NULL,
  `SERVER_ICON` tinytext CHARACTER SET utf16 COLLATE utf16_polish_ci NOT NULL,
  `DATE` date NOT NULL,
  `SERVER_ACTIVE` tinyint(1) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf16 COLLATE=utf16_polish_ci;

--
-- Dumping data for table `servers`
--
EOF
        log "\e[1;33m[CONSOLE: DB] Created database file: $DB_FILE"
    fi
}

generateServerId() {
    ensureDatabaseFile
    local max_id=0
    local id
    while IFS= read -r line; do
        if [[ "$line" == INSERT* ]]; then
            id=$(echo "$line" | sed -n 's/^INSERT INTO `servers`.*VALUES *( *\([0-9][0-9]*\).*/\1/p')
            if [[ -n "$id" && "$id" -gt "$max_id" ]]; then
                max_id="$id"
            fi
        fi
    done < "$DB_FILE"
    echo $((max_id + 1))
}

sqlEscape() {
    local value="$1"
    printf '%s' "$(printf '%s' "$value" | sed "s/'/''/g")"
}

getDefaultJavaVersion() {
    local version="$1"
    if [[ "$version" =~ ^1\.1[7-9] ]] || [[ "$version" =~ ^1\.2[0-9] ]]; then
        echo 21
    else
        echo 17
    fi
}

findServerIdByName() {
    local server_name="$1"
    ensureDatabaseFile
    awk -v name="$server_name" 'BEGIN { FS="VALUES" } /^INSERT INTO servers / {
        if (index($0, "'" name "'") > 0) {
            match($0, /\(([^,]+),/, a)
            if (a[1] != "") print a[1]
        }
    }' "$DB_FILE" | tail -n 1
}

removeServerFromDatabase() {
    local server_id="$1"
    local server_name="$2"
    ensureDatabaseFile

    if [[ -n "$server_id" ]]; then
        grep -F -v "($server_id," "$DB_FILE" > "$DB_FILE.tmp" && mv "$DB_FILE.tmp" "$DB_FILE"
        log "\e[1;33m[CONSOLE: DB] Removed server record by ID: $server_id"
        return
    fi

    if [[ -n "$server_name" ]]; then
        local pattern=",'$server_name',"
        grep -F -v "$pattern" "$DB_FILE" > "$DB_FILE.tmp" && mv "$DB_FILE.tmp" "$DB_FILE"
        log "\e[1;33m[CONSOLE: DB] Removed server record by name: $server_name"
        return
    fi

    log "\e[1;33m[CONSOLE: DB] Warning: removeServerFromDatabase called without id or name"
}

appendServerToDatabase() {
    local server_id="$1"
    local server_type="$2"
    local server_name="$3"
    local server_version="$4"
    local java_version="$5"
    local server_path="$6"
    local loader="$7"
    local loader_version="$8"
    local mods_amount="$9"
    local package_size="${10}"
    local icon="${11}"
    local date_value
    date_value=$(date '+%Y-%m-%d')
    local active=0

    local server_type_escaped
    local server_name_escaped
    local server_version_escaped
    local server_path_escaped
    local loader_escaped
    local loader_version_escaped
    local icon_escaped

    server_type_escaped=$(sqlEscape "$server_type")
    server_name_escaped=$(sqlEscape "$server_name")
    server_version_escaped=$(sqlEscape "$server_version")
    server_path_escaped=$(sqlEscape "$server_path")
    loader_escaped=$(sqlEscape "$loader")
    loader_version_escaped=$(sqlEscape "$loader_version")
    icon_escaped=$(sqlEscape "$icon")

    ensureDatabaseFile
    cat >> "$DB_FILE" <<EOF
INSERT INTO servers (SERVER_ID, SERVER_TYPE, SERVER_NAME, SERVER_VERSION, SERVER_JAVA_VERSION, SERVER_PATH, SERVER_LOADER, SERVER_LOADER_VERSION, SERVER_MODS_AMOUNT, SERVER_PACKAGE_SIZE, SERVER_ICON, DATE, SERVER_ACTIVE) VALUES
($server_id, '$server_type_escaped', '$server_name_escaped', '$server_version_escaped', $java_version, '$server_path_escaped', '$loader_escaped', '$loader_version_escaped', $mods_amount, $package_size, '$icon_escaped', '$date_value', $active);
EOF
    log "\e[1;33m[CONSOLE: DB] Appended server record to $DB_FILE: $server_name ($server_type)"
}

chooseServerType() {
    local ACTION=$1
    local options=()
    for entry in $BASE_SERVERS_DIR/*(/); do
        local folder="${entry:t}"
        if [[ "$folder" == "MAP" ]]; then
            # Include MAP subdirectories as separate options, prefixed with MAP/
            for maptype in "$entry"/*(/); do
                options+=("MAP > ${maptype:t} SERVER")
            done
        else
            options+=("$folder SERVER")
        fi
    done

    if ((${#options[@]} == 0)); then
        echo "\e[1;31m[CONSOLE: SERVERS] ERROR: No server folders found in $BASE_SERVERS_DIR/*"
        echo -ne "\e[1;37mPress 'ENTER' to return to main menu..."
        read PRESSED_KEY
        main
    fi

    while true; do
        clear
        if [[ "$ACTION" == "START" ]]; then
            center_text "[SELECT SERVER TYPE TO START]"
        elif [[ "$ACTION" == "STOP" ]]; then
            center_text "[SELECT SERVER TYPE TO STOP]"
        elif [[ "$ACTION" == "RESTART" ]]; then
            center_text "[SELECT SERVER TYPE TO RESTART]"
        elif [[ "$ACTION" == "DELETE" ]]; then
            center_text "[SELECT SERVER TYPE TO DELETE]"
        elif [[ "$ACTION" == "ARCHIVE" ]]; then
            center_text "[SELECT SERVER TYPE TO ARCHIVE]"
        fi
        echo ""
        # Print numbered options starting from 1
        for ((i = 1; i <= ${#options[@]}; i++)); do
            printf "\e[1;32m[%d]\e[1;33m %s\n" "$i" "${options[i]}"
        done
        echo -e "\e[1;31m[Q] QUIT"
        echo -ne "\n\e[1;33m> Select option [press 1-${#options[@]} or Q to quit]: \e[37m"
        read -rk1 PRESSED_KEY

        case "$PRESSED_KEY" in
            [qQ])
                clear
                center_text "[EXITING TO MAIN MENU]"
                main
                ;;
            [1-9]*)
                if ((PRESSED_KEY >= 1 && PRESSED_KEY <= ${#options[@]})); then
                    clear
                    local SERVER_TYPE="${options[PRESSED_KEY]% SERVER}"
                    if [[ "$ACTION" == "DELETE" ]]; then
                        source "$ABS_PATH/delete_server.sh"
                        deleteServer "$SERVER_TYPE" "$SERVER_NAME"
                    elif [[ "$ACTION" == "ARCHIVE" ]]; then
                        source "$ABS_PATH/archive_server.sh"
                        archiveServer "$SERVER_TYPE" "$SERVER_NAME"
                    else
                        source "$ABS_PATH/change_server_state.sh"
                        stopStartRestartServer "$ACTION" "$SERVER_TYPE" "$SERVER_NAME"
                    fi
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

serverMenu() {
    SERVER_TYPE=$1
    SERVER_PATH=$2
    SERVER_NAME=$3
    MINECRAFT_VERSION=$4

    center_text "[$SERVER_TYPE SERVER]"

    if [[ $SERVER_TYPE == "MAP" ]]; then
        SERVER_PATH="$BASE_SERVERS_DIR/$SERVER_TYPE"

        local options=()
        for entry in "$SERVER_PATH"/*(/); do
            options+=("${entry:t} SERVER")
        done

        if ((${#options[@]} == 0)); then
            echo -e "\e[1;31mNo server folders found in $SERVER_PATH/*\e[37m"
            echo -ne "\nPress any key to return to menu..."
            read -rk1
            source "$ABS_PATH/add_server.sh"
            addServer
        fi

        while true; do
            clear
            center_text "[ADD SERVER]"
            echo ""
            for ((i = 1; i <= ${#options[@]}; i++)); do
                printf "\e[1;32m[%d]\e[1;33m %s\n" "$i" "${options[i]}"
            done
            echo -e "\e[1;31m[Q] QUIT\e[0m"
            echo -ne "\n\e[1;33m> Select server type [press key 1–${#options[@]} or Q to quit]:\e[37m "
            read -rk1 PRESSED_KEY

            case "$PRESSED_KEY" in
                [qQ])
                    clear
                    source "$ABS_PATH/add_server.sh"
                    addServer
                    ;;
                [1-9] | [0-9])
                    if ((PRESSED_KEY >= 1 && PRESSED_KEY <= ${#options[@]})); then
                        clear
                        local MAP_TYPE="${options[PRESSED_KEY]% SERVER}"
                        center_text "[ADDING $MAP_TYPE SERVER]"
                        SERVER_PATH="$SERVER_PATH/$MAP_TYPE"
                        SERVER_TYPE="MAP"
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
    fi

    if [[ -z $SERVER_NAME ]]; then
        echo -ne "\n\e[1;37m[CONSOLE:    CREATOR] Enter server name: \e[37m"
        read SERVER_NAME
    fi

    SERVER_NAME=$(tr ' ' '-' <<< "$SERVER_NAME")
    mkdir -p "$SERVER_PATH/$SERVER_NAME"
    echo -e "\e[1;30m[CONSOLE:    CREATOR] Creating server folder: `ls -l "$SERVER_PATH" | grep "$SERVER_NAME"`"
    log "[CONSOLE:    CREATOR] Creating server folder: `ls -l "$SERVER_PATH" | grep "$SERVER_NAME"`"

    if [[ -z $MINECRAFT_VERSION ]]; then
        echo -ne "\e[1;37m[CONSOLE:    CREATOR] Enter minecraft version: \e[37m"
        read MINECRAFT_VERSION
        echo -e "\e[1;30m[CONSOLE:    CREATOR] Creating server config file...\e[37m"
        log "[CONSOLE:    CREATOR] Creating server config file..."
    fi

    SERVER_MINECRAFT_VERSION=$(tr -d ' ' <<< "$MINECRAFT_VERSION")
    SERVER_PATH="$SERVER_PATH/$SERVER_NAME"
    SERVER_ID=$(generateServerId)
    SERVER_JAVA_VERSION=$(getDefaultJavaVersion "$SERVER_MINECRAFT_VERSION")

    configureServer "$SERVER_TYPE" "$SERVER_NAME" "$SERVER_MINECRAFT_VERSION" "$SERVER_PATH" "$SERVER_ID"
    appendServerToDatabase "$SERVER_ID" "$SERVER_TYPE" "$SERVER_NAME" "$SERVER_MINECRAFT_VERSION" "$SERVER_JAVA_VERSION" "$SERVER_PATH" "" "" 0 0 ""

    echo -e "\e[1;30m[CONSOLE:    CREATOR] Server configuration done!\e[37m"
    echo -ne "\nPress any key to continue..."
    read -rk1
}

main() {
    while true; do
        unset SERVER_NAME
        clear
        center_text "[SERVER MANAGER]"
        echo -e "\n\e[1;32m[1]\e[1;33m START SERVER"
        echo -e "\e[1;32m[2]\e[1;33m STOP SERVER"
        echo -e "\e[1;32m[3]\e[1;33m RESTART SERVER"
        echo -e "\e[1;32m[4]\e[1;33m ADD SERVER"
        echo -e "\e[1;32m[5]\e[1;33m DELETE SERVER"
        echo -e "\e[1;32m[6]\e[1;33m ARCHIVE SERVER"
        echo -e "\e[1;32m[7]\e[1;33m KILL SERVER SESSIONS"
        echo -e "\e[1;32m[8]\e[1;33m CHANGE JAVA VERSION"
        echo -e "\e[1;31m[Q] QUIT"
        echo -ne "\n\e[1;33m> Select option [press key 1–5 or Q to quit]:\e[37m "
        read -rk1 PRESSED_KEY
        echo ""

        case "$PRESSED_KEY" in
            1)
                clear
                chooseServerType START
                ;;
            2)
                clear
                chooseServerType STOP
                ;;
            3)
                clear
                chooseServerType RESTART
                ;;
            4)
                clear
                source "$ABS_PATH/add_server.sh"
                addServer
                ;;
            5)
                clear
                chooseServerType DELETE
                ;;
            6)
                clear
                chooseServerType ARCHIVE
                ;;
            7)
                clear
                source "$ABS_PATH/kill_all_server_sessions.sh"
                killServerSessions
                ;;
            8)
                clear
                source "$ABS_PATH/java_version_switch.sh"
                javaVersionSwitch
                ;;
            [qQ])
                clear
                center_text "[ACTIVE SERVERS]"
                ACTIVE_SESSIONS=$(tmux list-sessions | sed 's/^/     - /; s/windows/window/')
                echo -e "\e[1;31mACTIVE SERVERS:\n$ACTIVE_SESSIONS"
                echo -e "\n\e[1;37m=====================================================================================\n"
                exit
                ;;
            *)
                echo -ne "\n\e[1;31mInvalid option '$PRESSED_KEY'. \nPress 'ENTER' to try again.\e[0m"
                read PRESSED_KEY
                ;;
        esac
    done
}

source "$ABS_PATH/help.sh"

loadCore

if [[ -n "$1" ]]; then
    ACTION="$1"
    SERVER_TYPE=$2
    SERVER_NAME=$3
    MINECRAFT_VERSION=$4
    SERVER_PATH=$5
    FORGE_VERSION=$6

    SERVER_ROOT="$BASE_SERVERS_DIR"
    SERVER_PATH="$SERVER_ROOT/$SERVER_TYPE/$SERVER_NAME"

    case "$ACTION" in
        --start-server)
            if [[ -z "$SERVER_TYPE" || -z "$SERVER_NAME" ]]; then
                echo -e "\e[1;31m[ERROR]\e[0m Missing server type or name. Try: \e[1;37m--start FORGE MyServer\e[0m"
                exit 1
            fi
            log "CLI: Starting server: name: --$SERVER_NAME | --type: $SERVER_TYPE."
            source "$ABS_PATH/change_server_state.sh"
            stopStartRestartServer START $SERVER_TYPE $SERVER_NAME
            exit 0
            ;;

        --stop-server)
            if [[ -z "$SERVER_TYPE" || -z "$SERVER_NAME" ]]; then
                echo -e "\e[1;31m[ERROR]\e[0m Missing server type or name. Try: \e[1;37m--stop FORGE MyServer\e[0m"
                exit 1
            fi
            log "CLI: Stopping server: name: --$SERVER_NAME | --type: $SERVER_TYPE."
            source "$ABS_PATH/change_server_state.sh"
            stopStartRestartServer STOP $SERVER_TYPE $SERVER_NAME
            exit 0
            ;;

        --restart-server)
            if [[ -z "$SERVER_TYPE" || -z "$SERVER_NAME" ]]; then
                echo -e "\e[1;31m[ERROR]\e[0m Missing server type or name. Try: \e[1;37m--restart-server FORGE MyServer\e[0m"
                exit 1
            fi
            log "CLI: Restarting server: name: --$SERVER_NAME | --type: $SERVER_TYPE."
            source "$ABS_PATH/change_server_state.sh"
            stopStartRestartServer RESTART $SERVER_TYPE $SERVER_NAME
            ;;

        --create-server)
            # ----------------------------------------------------------
            # Load &.env file
            # ----------------------------------------------------------
            PROPERTIES_FILE="$WEB_ROOT/.env/create-server-properties.env"
            if [[ -f "$PROPERTIES_FILE" ]]; then
                if [ -f $PROPERTIES_FILE ]; then
                    source $PROPERTIES_FILE
                else
                    echo "Error: .env file not found!"
                    exit 1
                fi

                SERVER_TYPE=$SERVER_TYPE
                SERVER_NAME=$SERVER_NAME
                MINECRAFT_VERSION=$MINECRAFT_VERSION
                FORGE_VERSION=$FORGE_VERSION
                rm -f $PROPERTIES_FILE
            fi

            missing_vars=()
            [[ -z "$SERVER_TYPE" ]] && missing_vars+=("SERVER_TYPE")
            [[ -z "$SERVER_NAME" ]] && missing_vars+=("SERVER_NAME")
            [[ -z "$MINECRAFT_VERSION" ]] && missing_vars+=("MINECRAFT_VERSION")
            [[ -z "$SERVER_PATH" ]] && missing_vars+=("SERVER_PATH")

            # Forge version is only required if server type is Forge
            if [[ "$SERVER_TYPE" == "Forge" && -z "$FORGE_VERSION" ]]; then
                missing_vars+=("FORGE_VERSION (required for Forge servers)")
            fi

            if ((${#missing_vars[@]})); then
                echo -e "\e[1;31m[ERROR]\e[0m Missing required argument(s): ${missing_vars[*]}"
                echo -e "Usage:\n  $0 SERVER_TYPE SERVER_NAME MINECRAFT_VERSION [FORGE_VERSION --optional]"
                exit 1
            fi

            log "CLI: Initiating creation wizard for $SERVER_TYPE server"
            clear
            serverMenu "$SERVER_TYPE" "$SERVER_ROOT/$SERVER_TYPE" "$SERVER_NAME" "$MINECRAFT_VERSION"
            exit 0
            ;;

        --delete-server)
            if [[ -z "$SERVER_TYPE" || -z "$SERVER_NAME" ]]; then
                echo -e "\e[1;31m[ERROR]\e[0m Usage: \e[1;37m--delete-server FORGE MyServer\e[0m"
                exit 1
            fi
            log "CLI: Deleting server: name: --$SERVER_NAME | --type: $SERVER_TYPE."
            source "$ABS_PATH/delete_server.sh"
            deleteServer $SERVER_TYPE $SERVER_NAME
            exit 0
            ;;

        --archive-server)
            if [[ -z "$SERVER_TYPE" || -z "$SERVER_NAME" ]]; then
                echo -e "\e[1;31m[ERROR]\e[0m Usage: \e[1;37m--archive-server FORGE MyServer\e[0m"
                exit 1
            fi
            log "CLI: Archiving server: name: --$SERVER_NAME | --type: $SERVER_TYPE."
            source "$ABS_PATH/archive_server.sh"
            archiveServer $SERVER_TYPE $SERVER_NAME
            exit 0
            ;;

        --status)
            if [[ -z "$SERVER_TYPE" || -z "$SERVER_NAME" ]]; then
                echo -e "\e[1;31m[ERROR]\e[0m Usage: \e[1;37m--status FORGE MyServer\e[0m"
                exit 1
            fi
            log "CLI: Checking status of server $SERVER_NAME ($SERVER_TYPE)"
            if tmux has-session -t "${SERVER_NAME//./_}" 2> /dev/null; then
                STATUS="running - \e[1;32mONLINE\e[0m"
            else
                STATUS="stopped - \e[1;31mOFFLINE\e[0m"
            fi
            echo -e "• \e[1;36m[$SERVER_TYPE] \e[0mServer \e[1;33m$SERVER_NAME\e[0m is $STATUS"
            log "CLI: [$SERVER_TYPE] Server $SERVER_NAME is $STATUS."
            exit 0
            ;;

        --status-all)
            log "CLI: Listing status of all servers"
            echo -e "\e[1;36m[STATUS REPORT]\e[0m All registered servers:\n"
            for TYPE_PATH in "$BASE_SERVERS_DIR"/*(/N); do
                SERVER_TYPE="${TYPE_PATH:t}"
                if [[ "$SERVER_TYPE" == "MAP" ]]; then
                    # MAP is a catalog directory containing sub-categories
                    for MAP_CAT_PATH in "$TYPE_PATH"/*(/N); do
                        MAP_CAT_NAME="${MAP_CAT_PATH:t}"
                        for SERVER_PATH in "$MAP_CAT_PATH"/*(/N); do
                            SERVER_NAME="${SERVER_PATH:t}"
                            # Check server status or list here
                            # Example (status):
                            if tmux has-session -t "${SERVER_NAME//./_}" 2> /dev/null; then
                                STATUS="\e[1;32mONLINE\e[0m"
                            else
                                STATUS="\e[1;31mOFFLINE\e[0m"
                            fi
                            echo -e "• \e[1;36m[MAP] > [$MAP_CAT_NAME] \e[1;33m$SERVER_NAME\e[0m - $STATUS"
                        done
                        echo "" # blank line after each type group
                    done
                else
                    # Normal server type: list servers directly
                    for SERVER_PATH in "$TYPE_PATH"/*(/N); do
                        SERVER_NAME="${SERVER_PATH:t}"
                        if tmux has-session -t "${SERVER_NAME//./_}" 2> /dev/null; then
                            STATUS="\e[1;32mONLINE\e[0m"
                        else
                            STATUS="\e[1;31mOFFLINE\e[0m"
                        fi
                        echo -e "• \e[1;36m[$SERVER_TYPE] \e[1;33m$SERVER_NAME\e[0m - $STATUS"
                    done
                fi

                echo "" # blank line after each type group
            done
            exit 0
            ;;

        --list)
            log "CLI: Listing all available servers"
            echo -e "\e[1;36m[AVAILABLE SERVERS]\e[0m\n"

            for TYPE_PATH in "$BASE_SERVERS_DIR"/*(/); do
                SERVER_TYPE="${TYPE_PATH:t}"
                echo -e "\e[1;34m[$SERVER_TYPE]\e[0m"

                found_any=false

                if [[ "$SERVER_TYPE" == "MAP" ]]; then
                    # MAP is a catalog: go into each category
                    for MAP_CAT_PATH in "$TYPE_PATH"/*(/); do
                        CAT_NAME="${MAP_CAT_PATH:t}"
                        for SERVER_DIR in "$MAP_CAT_PATH"/*(/); do
                            found_any=true
                            echo -e "  • \e[1;33m${SERVER_DIR:t}\e[0m  \e[1;90m(MAP → $CAT_NAME)\e[0m"
                        done
                    done
                else
                    # Normal types: list servers directly
                    for SERVER_DIR in "$TYPE_PATH"/*(/); do
                        found_any=true
                        echo -e "  • \e[1;33m${SERVER_DIR:t}\e[0m"
                    done
                fi

                if [[ $found_any == false ]]; then
                    echo -e "  \e[1;90m(no servers found)\e[0m"
                fi
                echo ""
            done

            exit 0
            ;;

        *)
            echo -e "\e[1;31m[ERROR]\e[0m Unknown command: $ACTION"
            echo -e "Use \e[1;37m--help\e[0m to see available commands."
            exit 1
            ;;
    esac
fi

main

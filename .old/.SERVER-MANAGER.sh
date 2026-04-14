#!/bin/zsh

# --------------------------------------------------------------------------------
# Description:  Automation of installing and managing Minecraft Servers
# Usage:        zsh .SERVER-MANAGER.sh
# Created by:   Kaiman
# Since:        21/08/2024 (DD/MM/YYYY)
# --------------------------------------------------------------------------------
# Version:      3.0 -- Major update with new features and improvements
# Last Updated: 14/04/2026 (DD/MM/YYYY)
# --------------------------------------------------------------------------------

# Global Variables
LOGGED_DATE=""
CURRENT_DATE=$(date '+%Y-%m-%d')
LOGGED_DAY=""
BASE_DIR="/home/Minecraft/SERVER"
BASE_SERVERS_DIR="/home/Minecraft/SERVERS"
LOGS_DIR="$BASE_DIR/logs"
LOG_FILE="$LOGS_DIR/latest.log"
PROPERTIES_FILE="$BASE_DIR/server-properties.env"

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

# ----------------------------------------------------------
# Center text & color prompt
# ----------------------------------------------------------
center_text() {
    local raw_text="$1"
    local clean_text=$(echo -e "$raw_text" | sed 's/\x1B\[[0-9;]*[mK]//g')  # Strip ANSI codes
    local line="====================================================================================="
    local line_width=${#line}
    local text_width=${#clean_text}
    local padding=$(( (line_width - text_width) / 2 ))

    echo -e "\e[1;37m$line\e[0m"  # Top line in white
    printf "\n%*s\e[1;33m%s\n" "$padding" "" "$(echo -e "$raw_text")"  # Center the original text (with color)
    echo -e "\n\e[1;37m$line\e[0m"  # Bottom line in white
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
# Java version switcher
# ----------------------------------------------------------
javaVersionSwitch() {
    center_text "[CHOOSE JAVA VERSION] $(date '+[DATE: %y/%m/%d | TIME: %H:%M:%S]')"

    # Switch Java Version
    echo -e "\n\e[1;33m[CONSOLE: JAVA] Switching Java version...\n\e[1;37m"
    sudo update-alternatives --config java

    # Confirmation message
    clear
    center_text "[ACTIVE JAVA VERSION] $(date '+[DATE: %y/%m/%d | TIME: %H:%M:%S]')"
    echo -e "\e[1;31m"
    java -version
    
    # End prompt
    echo -ne "\n\e[1;37mPress 'ENTER' to continue..."
    read PRESSED_KEY
}

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

# ----------------------------------------------------------
# Server configurator
# ----------------------------------------------------------
configureServer() {
    SERVER_TYPE=$1
    SERVER_NAME=$2
    MINECRAFT_VERSION=$3
    SERVER_PATH=$4
    SERVER_ID=$5

    ENV_FILE="server-properties.env"
    cat << EOF > $SERVER_PATH/$ENV_FILE
# Server Configuration
SERVER_STATUS=START
SERVER_TYPE=$SERVER_TYPE
SERVER_NAME=$SERVER_NAME
SERVER_PATH=$SERVER_PATH
SERVER_VERSION=$MINECRAFT_VERSION
SERVER_ID=$SERVER_ID
EOF

    log "\e[1;30m[CONSOLE:    CREATOR] Server config *.env file added: `ls -l $SERVER_PATH | grep "server-properties.env"`"
    # Ask for forge version if the server type is not Vanilla or Plugin
    if [[ "$SERVER_TYPE" != "VANILLA" && "$SERVER_TYPE" != "PLUGIN" ]]; then
        if [[ "$SERVER_TYPE" == "MAP" ]]; then
            echo -e "\e[1;30m[CONSOLE:    CREATOR] \e[37mIs your map modded? \e[31m[Y/N]\e[37m: "
            read MAP_TYPE

            # Convert the input to lowercase for case-insensitive comparison
            MAP_TYPE=$(echo "$MAP_TYPE" | tr '[:upper:]' '[:lower:]')
            if [[ $MAP_TYPE == "y" || $MAP_TYPE == "yes" || $MAP_TYPE == "1" ]]; then
                echo -ne "\e[1;30m[CONSOLE:    CREATOR] \e[37mEnter forge version \e[30m[14.23.5.2860]\e[37m: "
                read FORGE_VERSION
                if [[ -z "$FORGE_VERSION" || "$FORGE_VERSION" =~ ^\s*$ ]]; then
                    FORGE_VERSION="14.23.5.2860"
                fi
                log "[CONSOLE:    CREATOR] Entered forge version: $FORGE_VERSION"
            fi
        else
            echo -ne "\e[1;30m[CONSOLE:    CREATOR] \e[37mEnter forge version \e[30m[14.23.5.2860]\e[37m: "
            read FORGE_VERSION
            if [[ -z "$FORGE_VERSION" || "$FORGE_VERSION" =~ ^\s*$ ]]; then
                FORGE_VERSION="14.23.5.2860"
            fi
            log "[CONSOLE:    CREATOR] Entered forge version: $FORGE_VERSION"
        fi
    fi

    if [[ "$SERVER_TYPE" == "VANILLA" && ! -f "$SERVER_PATH/minecraft_server.$MINECRAFT_VERSION.jar" || -z "$FORGE_VERSION" && ! -f "$SERVER_PATH/minecraft_server.$MINECRAFT_VERSION.jar" ]]; then
        log "\e[1;30m[CONSOLE: DOWNLOADER] Downloading Minecraft server JAR for version $MINECRAFT_VERSION...\e[34m"
        # Fetch the Mojang version manifest
        VERSION_MANIFEST_URL="https://launchermeta.mojang.com/mc/game/version_manifest.json"
        VERSION_MANIFEST=$(curl -s "$VERSION_MANIFEST_URL")
        # Extract the specific version JSON URL
        VERSION_URL=$(echo "$VERSION_MANIFEST" | jq -r --arg ver "$MINECRAFT_VERSION" '.versions[] | select(.id == $ver) | .url')
        if [[ -z "$VERSION_URL" ]]; then
            log "\e[1;31m[CONSOLE: DOWNLOADER] ERROR: Could not find metadata for Minecraft version $MINECRAFT_VERSION."
            exit 1
        fi
        # Extract the server JAR URL from the version metadata
        SERVER_JAR_URL=$(curl -s "$VERSION_URL" | jq -r '.downloads.server.url')
        if [[ -z "$SERVER_JAR_URL" ]]; then
            log "\e[1;31m[CONSOLE: DOWNLOADER] ERROR: Could not find server JAR download URL for version $MINECRAFT_VERSION."
            exit 1
        fi
        # Download the server jar into the server directory with retry mechanism
        RETRY_COUNT=3
        RETRY_DELAY=5
        for i in $(seq 1 $RETRY_COUNT); do
            curl -L -o "$SERVER_PATH/minecraft_server.$MINECRAFT_VERSION.jar" "$SERVER_JAR_URL" && break
            log "\e[1;33m[CONSOLE: DOWNLOADER] WARN: Attempt $i failed, retrying in $RETRY_DELAY seconds..."
            sleep $RETRY_DELAY
        done
        # Check if download was successful
        if [[ ! -f "$SERVER_PATH/minecraft_server.$MINECRAFT_VERSION.jar" ]]; then
            log "\e[1;31m[CONSOLE: DOWNLOADER] ERROR: Failed to download the server jar after $RETRY_COUNT attempts."
            exit 1
        fi
        log "\e[1;30m[CONSOLE: DOWNLOADER] SUCCESS: Minecraft server JAR downloaded to $SERVER_PATH/minecraft_server.$MINECRAFT_VERSION.jar: `ls -l $SERVER_PATH | grep "minecraft_server.$MINECRAFT_VERSION.jar"`"
    fi

    # === Download Forge Installer (for Forge server only) ===
    if [[ "$SERVER_TYPE" == "FORGE" && ! -f "$SERVER_PATH/forge-$MINECRAFT_VERSION-$FORGE_VERSION.jar" ]]; then
        log "\e[1;30m[CONSOLE: DOWNLOADER] Downloading forge-$MINECRAFT_VERSION-$FORGE_VERSION-installer.jar...\e[0;34m"
        # Forge installer download URL
        FORGE_INSTALLER_URL="https://maven.minecraftforge.net/net/minecraftforge/forge/$MINECRAFT_VERSION-$FORGE_VERSION/forge-$MINECRAFT_VERSION-$FORGE_VERSION-installer.jar"
        # Download the Forge installer
        curl -o "$SERVER_PATH/forge-$MINECRAFT_VERSION-$FORGE_VERSION-installer.jar" "$FORGE_INSTALLER_URL"
        if [[ -f "$SERVER_PATH/forge-$MINECRAFT_VERSION-$FORGE_VERSION-installer.jar" ]]; then
            log "\e[1;30m[CONSOLE: DOWNLOADER] SUCCESS: Successfully downloaded Forge installer."
            # Run the Forge installer to install Forge into the server directory
            log "\e[1;30m[CONSOLE:      FORGE] Installing forge...\e[0;34m"
            cd "$SERVER_PATH" || {
                log "\e[1;31m[CONSOLE:      FORGE] ERROR: Failed to change directory to $SERVER_PATH"
                exit 1
            }
            # Run the Forge installer (headless installation)
            java -jar "forge-$MINECRAFT_VERSION-$FORGE_VERSION-installer.jar" --installServer
            # Check if the Forge server .jar file is created
            if [[ -f "$SERVER_PATH/forge-$MINECRAFT_VERSION-$FORGE_VERSION.jar" ]]; then
                log "\e[1;30m[CONSOLE:      FORGE] SUCCESS: Forge installation successful: `ls -l "$SERVER_PATH/" | grep "forge-$MINECRAFT_VERSION-$FORGE_VERSION.jar"`"
                log "\e[1;30m[CONSOLE:      FORGE] Deleting forge installer: forge-$MINECRAFT_VERSION-$FORGE_VERSION-installer.jar `rm "$SERVER_PATH/forge-$MINECRAFT_VERSION-$FORGE_VERSION-installer.jar"`"
                log "\e[1;30m[CONSOLE:      FORGE] Deleting forge installer log: forge-$MINECRAFT_VERSION-$FORGE_VERSION-installer.jar.log `rm "$SERVER_PATH/forge-$MINECRAFT_VERSION-$FORGE_VERSION-installer.jar.log"`"
            else
                log "\e[1;31m[CONSOLE:      FORGE] ERROR: Forge installation failed."
                exit 1
            fi
        else
            log "\e[1;31m[CONSOLE:      FORGE] ERROR: Failed to download Forge installer."
            exit 1
        fi
    fi

    DATE=$(date "+DATE: %y/%m/%d | TIME: %H:%M:%S")
    # Prepare start-server.sh based on server type (Vanilla or Plugin)
    if [[ "$SERVER_TYPE" == "VANILLA" || "$SERVER_TYPE" == "PLUGIN" || -z "$FORGE_VERSION" ]]; then
        cat << EOF > "$SERVER_PATH/start-server.sh"
#!/bin/bash

# --------------------------------------------------------------------------------
# Script Name:  start-server.sh
# Description:  Starts a Minecraft Forge server in a tmux session.
#               If the server is already running, it displays the current status.
# Usage:        ./start-server.sh
# Server:       [$SERVER_NAME]
# Created:      [$DATE]
# --------------------------------------------------------------------------------

# Server Configuration
SERVER_NAME="$SERVER_NAME"                                             # Name of the tmux session
MINECRAFT_VERSION="$MINECRAFT_VERSION"                                          # Minecraft version
SERVER_JAR="minecraft_server.$MINECRAFT_VERSION.jar"                                # Server JAR file
SERVER_PATH="$SERVER_PATH/"              # The directory of the server
PROPERTIES_FILE="/home/Minecraft/SERVER/env/server-properties.env"  # The dest directory of *.env file
MINMEM="8G"                                                         # Minimum memory allocation
MAXMEM="16G"                                                        # Maximum memory allocation
JAVA_PATH=\$(which java)                                             # Path to the Java executable
TMUX_PATH=\$(which tmux)                                             # Path to the tmux executable

# ----------------------------------------------------------
# Switch Java version based on Minecraft version
# ----------------------------------------------------------
javaVersionSwitch() {
    local MINECRAFT_VERSION="\$1"
    local JAVA_VERSION=""

    if [[ "\$MINECRAFT_VERSION" =~ ^1\\.([0-9]|1[0-6])(\\..*)?\$ ]]; then
        JAVA_VERSION="8"
    elif [[ "\$MINECRAFT_VERSION" =~ ^1\\.1[7-9](\\..*)?\$ ]]; then
        JAVA_VERSION="17"
    elif [[ "\$MINECRAFT_VERSION" =~ ^1\\.2[0-9](\\..*)?\$ ]]; then
        JAVA_VERSION="21"
    else
        JAVA_PROMPT=\`echo -e "\\n\\e[1;33m[CONSOLE:  \\e[31mERROR\\e[33m] \\e[31mUnsupported or unknown Minecraft version: \$MINECRAFT_VERSION"\`
        exit 1
    fi

    local ACTIVE_JAVA_VERSION=\$(java -version 2>&1 | awk -F '"' '/version/ {print \$2}')
    local ACTIVE_JAVA_VERSION="\${ACTIVE_JAVA_VERSION%%.*}"
    [[ "\$ACTIVE_JAVA_VERSION" == "1" ]] && ACTIVE_JAVA_VERSION="8"

    if [[ "\$JAVA_VERSION" != "\$ACTIVE_JAVA_VERSION" ]]; then
        case "\$JAVA_VERSION" in
            8)  sudo update-alternatives --set java /usr/lib/jvm/java-8-openjdk-arm64/bin/java ;;
            17) sudo update-alternatives --set java /usr/lib/jvm/java-17-openjdk-arm64/bin/java ;;
            21) sudo update-alternatives --set java /usr/lib/jvm/java-21-openjdk-arm64/bin/java ;;
        esac
        JAVA_PROMPT=\$(
            echo -e "\e[1;31m" 
            java -version 2>&1
            echo -e "\n\e[1;33m[CONSOLE:   JAVA] \e[37mJava version switched to \$JAVA_VERSION for Minecraft \$MINECRAFT_VERSION"
        )
    else
        JAVA_PROMPT=\$(
            echo -e "\e[1;31m"
            java -version 2>&1
            echo -e "\n\e[1;33m[CONSOLE:   JAVA] \e[37mJava version \$JAVA_VERSION is currently active for Minecraft \$MINECRAFT_VERSION"
        )
    fi
}
javaVersionSwitch "\$MINECRAFT_VERSION"

# ----------------------------------------------------------
# Print centered & colorized text
# ----------------------------------------------------------
center_text() {
    local raw_text="\$1"
    local clean_text=\$(echo -e "\$raw_text" | sed 's/\\x1B\\[[0-9;]*[mK]//g')  # Strip ANSI codes
    local line="====================================================================================="
    local line_width=\${#line}
    local text_width=\${#clean_text}
    local padding=\$(( (line_width - text_width) / 2 ))

    echo -e "\\e[1;37m\$line\\e[0m"  # Top line in white
    printf "\\n%*s\\e[1;33m%s\\n" "\$padding" "" "\$(echo -e "\$raw_text")"  # Center the original text (with color)
    echo -e "\\n\\e[1;37m\$line\\e[0m"  # Bottom line in white
}

# ----------------------------------------------------------
# Go to the server directory
# ----------------------------------------------------------
cd "\$SERVER_PATH" || {
    echo -e "\\e[1;33m[CONSOLE:  \\e[31mERROR\\e[33m] \\e[31mFailed to change directory to \$SERVER_PATH."
    exit 1
}

# ----------------------------------------------------------
# Check if the server is already running
# ----------------------------------------------------------
checkServer() {
    clear
    if tmux has-session -t "\$SERVER_NAME" 2>/dev/null; then
        center_text "[SERVER STATUS: \\e[32mONLINE\\e[33m \`date "+| DATE: %y/%m/%d | TIME: %H:%M:%S"\`]"
        echo -e "\$JAVA_PROMPT"
        local FREE_MEM_GB=\$(free -m | awk '/^Mem:/ { printf "%.2f", \$7 / 1024 }')
        echo -e "\\e[33m[CONSOLE: MEMORY] \\e[37mAllocated: \\e[30mMIN: \$MINMEM\\e[37m | \\e[30mMAX: \$MAXMEM\\e[37m | \\e[37mFree: \\e[30m\${FREE_MEM_GB}GB\\e[37m"
        echo -e "\\e[33m[CONSOLE: SERVER] \\e[37mServer \\e[34m\$SERVER_NAME\\e[37m state unchanged \u2014 \\e[32mONLINE\\e[37m"
        # Active sessions: green current, gray inactive (instead of black)
        ACTIVE_SESSIONS=\$(tmux list-sessions | awk -v T="\$SERVER_NAME" '{
            s=\$1; sub(":", "", s);
            c=(s==T)?"31":"30";  # green for active session, bright black (gray) for others
            printf "\\033[1;%sm     - %s\\033[0m\\n", c, \$0
        }')
        echo -e "\\e[33m[CONSOLE: STATUS] \\e[37mActive servers listed below:\\n\$ACTIVE_SESSIONS"
        echo -e "\\n\\e[37m=====================================================================================\\e[0m"
    else
        center_text "[STARTING SERVER: \\e[31mOFFLINE\\e[33m -> \\e[32mONLINE\\e[33m \`date "+| DATE: %y/%m/%d | TIME: %H:%M:%S"\`]"
        echo -e "\$JAVA_PROMPT"
        \$TMUX_PATH new-session -ds "\$SERVER_NAME" "cd \$(pwd) && \$JAVA_PATH -Xmx\$MAXMEM -Xms\$MINMEM -jar \$SERVER_JAR nogui"
        local FREE_MEM_GB=\$(free -m | awk '/^Mem:/ { printf "%.2f", \$7 / 1024 }')
        echo -e "\\e[33m[CONSOLE: MEMORY] \\e[37mAllocated: \\e[30mMIN: \$MINMEM\\e[37m | \\e[30mMAX: \$MAXMEM\\e[37m | \\e[37mFree: \\e[30m\${FREE_MEM_GB}GB\\e[37m"
        echo -e "\\e[33m[CONSOLE: SERVER] \\e[37mServer \\e[34m\$SERVER_NAME\\e[37m successfully started \u2014 \\e[32mONLINE"
        ACTIVE_SESSIONS=\$(tmux list-sessions | awk -v T="\$SERVER_NAME" '{
            s=\$1; sub(":", "", s);
            c=(s==T)?"31":"30";
            printf "\\033[1;%sm     - %s\\033[0m\\n", c, \$0
        }')
        echo -e "\\e[33m[CONSOLE: STATUS] \\e[37mActive servers listed below:\\n\$ACTIVE_SESSIONS"
        echo -e "\\n\\e[37m=====================================================================================\\e[0m"
    fi
}
checkServer
exit 0
EOF
    else
        cat << EOF > "$SERVER_PATH/start-server.sh"
#!/bin/bash

# --------------------------------------------------------------------------------
# Script Name:  start-server.sh
# Description:  Starts a Minecraft Forge server in a tmux session.
#               If the server is already running, it displays the current status.
# Usage:        ./start-server.sh
# Server:       [$SERVER_NAME]
# Created:      [$DATE]
# --------------------------------------------------------------------------------

# Server Configuration
SERVER_NAME="$SERVER_NAME"                                             # Name of the tmux session
MINECRAFT_VERSION="$MINECRAFT_VERSION"                                          # Minecraft version
FORGE_VERSION="$FORGE_VERSION"                                             # Forge server version
FORGE_JAR="forge-$MINECRAFT_VERSION-$FORGE_VERSION.jar"                                # Forge server JAR file
SERVER_PATH="$SERVER_PATH/"              # The directory of the server
PROPERTIES_FILE="/home/Minecraft/SERVER/env/server-properties.env"  # The dest directory of *.env file
MINMEM="8G"                                                         # Minimum memory allocation
MAXMEM="16G"                                                        # Maximum memory allocation
JAVA_PATH=\$(which java)                                             # Path to the Java executable
TMUX_PATH=\$(which tmux)                                             # Path to the tmux executable

# ----------------------------------------------------------
# Switch Java version based on Minecraft version
# ----------------------------------------------------------
javaVersionSwitch() {
    local MINECRAFT_VERSION="\$1"
    local JAVA_VERSION=""

    if [[ "\$MINECRAFT_VERSION" =~ ^1\\.([0-9]|1[0-6])(\\..*)?\$ ]]; then
        JAVA_VERSION="8"
    elif [[ "\$MINECRAFT_VERSION" =~ ^1\\.1[7-9](\\..*)?\$ ]]; then
        JAVA_VERSION="17"
    elif [[ "\$MINECRAFT_VERSION" =~ ^1\\.2[0-9](\\..*)?\$ ]]; then
        JAVA_VERSION="21"
    else
        JAVA_PROMPT=\`echo -e "\\n\\e[1;33m[CONSOLE:  \\e[31mERROR\\e[33m] \\e[31mUnsupported or unknown Minecraft version: \$MINECRAFT_VERSION"\`
        exit 1
    fi

    local ACTIVE_JAVA_VERSION=\$(java -version 2>&1 | awk -F '"' '/version/ {print \$2}')
    local ACTIVE_JAVA_VERSION="\${ACTIVE_JAVA_VERSION%%.*}"
    [[ "\$ACTIVE_JAVA_VERSION" == "1" ]] && ACTIVE_JAVA_VERSION="8"

    if [[ "\$JAVA_VERSION" != "\$ACTIVE_JAVA_VERSION" ]]; then
        case "\$JAVA_VERSION" in
            8)  sudo update-alternatives --set java /usr/lib/jvm/java-8-openjdk-arm64/bin/java ;;
            17) sudo update-alternatives --set java /usr/lib/jvm/java-17-openjdk-arm64/bin/java ;;
            21) sudo update-alternatives --set java /usr/lib/jvm/java-21-openjdk-arm64/bin/java ;;
        esac
        JAVA_PROMPT=\$(
            echo -e "\e[1;31m" 
            java -version 2>&1
            echo -e "\n\e[1;33m[CONSOLE:   JAVA] \e[37mJava version switched to \$JAVA_VERSION for Minecraft \$MINECRAFT_VERSION"
        )
    else
        JAVA_PROMPT=\$(
            echo -e "\e[1;31m"
            java -version 2>&1
            echo -e "\n\e[1;33m[CONSOLE:   JAVA] \e[37mJava version \$JAVA_VERSION is currently active for Minecraft \$MINECRAFT_VERSION"
        )
    fi
}
javaVersionSwitch "\$MINECRAFT_VERSION"

# ----------------------------------------------------------
# Print centered & colorized text
# ----------------------------------------------------------
center_text() {
    local raw_text="\$1"
    local clean_text=\$(echo -e "\$raw_text" | sed 's/\\x1B\\[[0-9;]*[mK]//g')  # Strip ANSI codes
    local line="====================================================================================="
    local line_width=\${#line}
    local text_width=\${#clean_text}
    local padding=\$(( (line_width - text_width) / 2 ))

    echo -e "\\e[1;37m\$line\\e[0m"  # Top line in white
    printf "\\n%*s\\e[1;33m%s\\n" "\$padding" "" "\$(echo -e "\$raw_text")"  # Center the original text (with color)
    echo -e "\\n\\e[1;37m\$line\\e[0m"  # Bottom line in white
}

# ----------------------------------------------------------
# Go to the server directory
# ----------------------------------------------------------
cd "\$SERVER_PATH" || {
    echo -e "\\e[1;33m[CONSOLE:  \\e[31mERROR\\e[33m] \\e[31mFailed to change directory to \$SERVER_PATH."
    exit 1
}

# ----------------------------------------------------------
# Check if the server is already running
# ----------------------------------------------------------
checkServer() {
    clear
    if tmux has-session -t "\$SERVER_NAME" 2>/dev/null; then
        center_text "[SERVER STATUS: \\e[32mONLINE\\e[33m \`date "+| DATE: %y/%m/%d | TIME: %H:%M:%S"\`]"
        echo -e "\$JAVA_PROMPT"
        local FREE_MEM_GB=\$(free -m | awk '/^Mem:/ { printf "%.2f", \$7 / 1024 }')
        echo -e "\\e[33m[CONSOLE: MEMORY] \\e[37mAllocated: \\e[30mMIN: \$MINMEM\\e[37m | \\e[30mMAX: \$MAXMEM\\e[37m | \\e[37mFree: \\e[30m\${FREE_MEM_GB}GB\\e[37m"
        echo -e "\\e[33m[CONSOLE: SERVER] \\e[37mServer  \\e[34m\$SERVER_NAME\\e[37m state unchanged \u2014 \\e[32mONLINE\\e[37m"
        # Active sessions: green current, gray inactive (instead of black)
        ACTIVE_SESSIONS=\$(tmux list-sessions | awk -v T="\$SERVER_NAME" '{
            s=\$1; sub(":", "", s);
            c=(s==T)?"31":"30";  # green for active session, bright black (gray) for others
            printf "\\033[1;%sm     - %s\\033[0m\\n", c, \$0
        }')
        echo -e "\\e[33m[CONSOLE: STATUS] \\e[37mActive servers listed below:\\n\$ACTIVE_SESSIONS"
        echo -e "\\n\\e[37m=====================================================================================\\e[0m"
    else
        center_text "[STARTING SERVER: \\e[31mOFFLINE\\e[33m -> \\e[32mONLINE\\e[33m \`date "+| DATE: %y/%m/%d | TIME: %H:%M:%S"\`]"
        echo -e "\$JAVA_PROMPT"
        \$TMUX_PATH new-session -ds "\$SERVER_NAME" "cd \$(pwd) && \$JAVA_PATH -Xmx\$MAXMEM -Xms\$MINMEM -jar \$FORGE_JAR nogui"
        local FREE_MEM_GB=\$(free -m | awk '/^Mem:/ { printf "%.2f", \$7 / 1024 }')
        echo -e "\\e[33m[CONSOLE: MEMORY] \\e[37mAllocated: \\e[30mMIN: \$MINMEM\\e[37m | \\e[30mMAX: \$MAXMEM\\e[37m | \\e[37mFree: \\e[30m\${FREE_MEM_GB}GB\\e[37m"
        echo -e "\\e[33m[CONSOLE: SERVER] \\e[37mServer \\e[34m\$SERVER_NAME\\e[37m successfully started \u2014 \\e[32mONLINE"
        ACTIVE_SESSIONS=\$(tmux list-sessions | awk -v T="\$SERVER_NAME" '{
            s=\$1; sub(":", "", s);
            c=(s==T)?"31":"30";
            printf "\\033[1;%sm     - %s\\033[0m\\n", c, \$0
        }')
        echo -e "\\e[33m[CONSOLE: STATUS] \\e[37mActive servers listed below:\\n\$ACTIVE_SESSIONS"
        echo -e "\\n\\e[37m=====================================================================================\\e[0m"
    fi
}
checkServer
exit 0
EOF
    fi
    chmod +x "$SERVER_PATH/start-server.sh"
    echo -e "\e[1;30m[CONSOLE:    CREATOR] Server startup file created: `ls -l $SERVER_PATH | grep "start-server.sh"`"
    log "[CONSOLE:    CREATOR] Server startup file created: `ls -l $SERVER_PATH | grep "start-server.sh"`"

    # Copy and extract *.zip package if exist
    MODPACK_ZIP="/var/www/html/files/modpacks/$SERVER_NAME/$SERVER_NAME.zip"
    if [[ -n "$FORGE_VERSION" ]]; then
        if [[ -f "$MODPACK_ZIP" ]]; then
            echo -e "\e[1;30m[CONSOLE:    CREATOR] ZIP: Found modpack: \e[34m$MODPACK_ZIP\e[33m"
            log "[CONSOLE:    CREATOR] ZIP: Found modpack: $MODPACK_ZIP"

            # Move zip to server path
            if cp "$MODPACK_ZIP" "$SERVER_PATH/"; then
                echo -e "\e[1;30m[CONSOLE:    CREATOR] ZIP: Copied modpack to: $SERVER_PATH"
                log "[CONSOLE:    CREATOR] ZIP: Copied modpack to: $SERVER_PATH"
            else
                echo -e "\e[1;31m[CONSOLE:    CREATOR] ZIP: ERROR: Failed to copy modpack to: $SERVER_PATH\e[33m"
                log "[CONSOLE:    CREATOR] ZIP: ERROR: Failed to copy modpack zip to: $SERVER_PATH"
                exit 1
            fi

            # Navigate to server path
            if cd "$SERVER_PATH"; then
                echo -e "\e[1;30m[CONSOLE:    CREATOR] ZIP: Changed directory to: $SERVER_PATH"
                log "[CONSOLE:    CREATOR] ZIP: Changed directory to: $SERVER_PATH"
            else
                echo -e "\e[1;31m[CONSOLE:    CREATOR] ZIP: ERROR: Failed to change directory to: $SERVER_PATH"
                log "[CONSOLE:    CREATOR] ZIP: ERROR: Failed to change directory to: $SERVER_PATH"
                exit 1
            fi

            echo -e "\e[1;33m[CONSOLE:    EXTRACT] Extracting $SERVER_NAME.zip..."
            log "[CONSOLE:    EXTRACT] Extracting $SERVER_NAME.zip..."
            # Unzip and check result
            if unzip -o "$SERVER_NAME.zip"; then
                echo -e "\e[33m[CONSOLE:    EXTRACT] \e[32mSUCCESS: \e[33mModpack extracted successfully: `ls -l "$SERVER_PATH" | grep "$SERVER_NAME.zip"`"
                log "[CONSOLE:    EXTRACT] SUCCESS: Modpack extracted successfully: `ls -l "$SERVER_PATH" | grep "$SERVER_NAME.zip"`"
            else
                echo -e "\e[31m[CONSOLE:    EXTRACT] ERROR: Failed to unzip $SERVER_NAME.zip"
                log "[CONSOLE:    EXTRACT] ERROR: Failed to unzip $SERVER_NAME.zip"
                exit 1
            fi

            # Removing *.zip package
            echo -e "\e[1;30m[CONSOLE:    CREATOR] ZIP: Deleting $SERVER_NAME.zip..."
            log "[CONSOLE:    CREATOR] ZIP: Deleting $SERVER_NAME.zip..."
            rm "$SERVER_NAME.zip"
            if [[ -f "$SERVER_NAME.zip" ]]; then
                echo -e "\e[1;30m[CONSOLE:    CREATOR] ZIP: $SERVER_NAME.zip deleted."
                log "[CONSOLE:    CREATOR] ZIP: $SERVER_NAME.zip deleted."
            else
                echo -e "\e[1;31m[CONSOLE:    CREATOR] ZIP: ERROR: Filed to delete $SERVER_NAME.zip."
                log "[CONSOLE:    CREATOR] ZIP: ERROR: Filed to delete $SERVER_NAME.zip"
            fi
        else
            echo -e "\e[1;33m[CONSOLE:    CREATOR] ZIP:  WARN: No modpack *.zip found at: $MODPACK_ZIP"
            log "[CONSOLE:    CREATOR] ZIP: WARN: No modpack *.zip found  at: $MODPACK_ZIP"
            echo -e "\e[1;30m[CONSOLE:    CREATOR] Skipping modpack extraction."
            log "[CONSOLE:    CREATOR] Skipping modpack extraction."
        fi
    fi

    # Accepting eula
    echo "\e[1;30m[CONSOLE:    CREATOR] Accepting server eula..."
    log "[CONSOLE:    CREATOR] Accepting server eula..."
    cat << EOF > "$SERVER_PATH/eula.txt"
#By changing the setting below to TRUE you are indicating your agreement to our EULA (https://account.mojang.com/documents/minecraft_eula).
#$(LC_TIME=en_US.UTF-8 date +"%a %b %d %T %Z %Y")
eula=true
EOF
    log "\e[1;30m[CONSOLE:    CREATOR] Server eula accepted: `ls -l $SERVER_PATH | grep "eula.txt"`"
    # Change server.properties
    log "\e[1;30m[CONSOLE:    CREATOR] Creating server.properties file..."
    SERVER_PROPERTIES="$SERVER_PATH/server.properties"
cat > "$SERVER_PROPERTIES" <<EOF
allow-flight=true
enable-command-block=true
spawn-protection=0
view-distance=8
motd="§6§l$SERVER_NAME§r §f- version: $MINECRAFT_VERSION"
max-players=14
online-mode=true
network-compression-threshold=256
EOF
    if [[ -f "$SERVER_PROPERTIES" ]]; then
        log "\e[1;30m[CONSOLE:    CREATOR] Created server.properties file: `ls -l "$SERVER_PATH" | grep -E "server\.properties$"`"
    else
        log "\e[1;31m[CONSOLE:    CREATOR] ERROR: Failed to create server.properties file."
    fi
}

stopStartRestartServer() {
    ACTION=$1
    SERVER_TYPE=$2
    SERVER_NAME=$3
    SERVER_PATH="/home/Minecraft/SERVERS"
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
        if [[ -f "/home/Minecraft/SERVER/env/server-properties-$SERVER_NAME.env" ]]; then
            sed -i 's/^server-port=.*/server-port=25565/' "$SERVER_DIR/$SERVER_NAME/server.properties"
            DEST="/home/Minecraft/SERVER/env/server-properties-$SERVER_NAME.env"
        else
            DEST="/home/Minecraft/SERVER/env/server-properties.env"
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
            log "\e[1;30m[CONSOLE: SERVERS] Server \e[34m$SERVER_NAM\e[30m is \e[31mOFFLINE\e[30m."
        fi

        # Starting server
        log "\e[1;30m[CONSOLE: SERVERS] Setting up server \e[34m$SERVER_NAME\e[30m..."
        SOURCE="$SERVER_PATH/$SERVER_TYPE/$SERVER_NAME/server-properties.env"
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
                if [[ -f "/home/Minecraft/SERVER/env/server-properties-$SERVER_NAME.env" ]]; then
                    sed -i 's/^server-port=.*/server-port=25565/' "$SERVER_DIR/$SERVER_NAME/server.properties"
                    DEST="/home/Minecraft/SERVER/env/server-properties-$SERVER_NAME.env"
                else
                    DEST="/home/Minecraft/SERVER/env/server-properties.env"
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
                curl -s --insecure "https://localhost/SERVER/php/changeServerStatus.php?server_status=OFFLINE&server_id=$SERVER_ID"
                if rm "$DEST"; then
                    log "\e[1;30m[CONSOLE: SERVERS] Succesfully deleted: $DEST"
                else
                    log "\e[1;31m[CONSOLE: SERVERS] ERROR: Failed to delete: $DEST"
                fi
                sleep 1
                # Checking is server session was killed
                if ! tmux has-session -t "$SERVER_NAME" 2>/dev/null; then
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

                SOURCE="$SERVER_PATH/$SERVER_TYPE/$SERVER_NAME/server-properties.env"
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
                curl -s --insecure "https://localhost/SERVER/php/changeServerStatus.php?server_status=ONLINE&server_id=$SERVER_ID"
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

deleteServer() {
    SERVER_TYPE=$1
    SERVER_NAME=$2
    SERVER_PATH="/home/Minecraft/SERVERS"
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

            if [[ -f "/home/Minecraft/SERVER/env/server-properties-$SERVER_NAME.env" ]]; then
                sed -i 's/^server-port=.*/server-port=25565/' "$SERVER_DIR/$SERVER_NAME/server.properties"
                DEST="/home/Minecraft/SERVER/env/server-properties-$SERVER_NAME.env"
            else
                DEST="/home/Minecraft/SERVER/env/server-properties.env"
            fi

            log "\e[1;30m[CONSOLE: SERVERS] Stopping server: $SERVER_NAME..."
            log "\e[1;30m[CONSOLE: SERVERS] Sending STOP command to server $SERVER_NAME..."
            log "\e[1;30m[CONSOLE: SERVERS] Server $SERVER_NAME: Shutting down..."
            tmux send-keys -t "$SERVER_NAME" "stop" C-m
            sleep 6
            log "\e[1;30m[CONSOLE: SERVERS] Server $SERVER_NAME stopped..."

            loadEnvConfig $DEST
            log "\e[1;30m[CONSOLE: SERVERS] Setting server $SERVER_NAME state to \e[31mOFFLINE\e[30m..."
            curl -s --insecure "https://localhost/SERVER/php/changeServerStatus.php?server_status=OFFLINE&server_id=$SERVER_ID"

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

archiveServer() {
    SERVER_TYPE=$1
    SERVER_NAME=$2
    SERVER_PATH="/home/Minecraft/SERVERS"
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
            echo -ne "\n\e[1;33m[CONSOLE: SERVERS] Select server type [press key 1–${#options[@]} or Q to quit]:\e[37m "
            read -rk1 PRESSED_KEY

            case "$PRESSED_KEY" in
                [qQ])
                    clear
                    chooseServerType ARCHIVE
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

            if [[ -f "/home/Minecraft/SERVER/env/server-properties-$SERVER_NAME.env" ]]; then
                sed -i 's/^server-port=.*/server-port=25565/' "$SERVER_DIR/$SERVER_NAME/server.properties"
                DEST="/home/Minecraft/SERVER/env/server-properties-$SERVER_NAME.env"
            else
                DEST="/home/Minecraft/SERVER/env/server-properties.env"
            fi

            log "\e[1;30m[CONSOLE: SERVERS] Stopping server: $SERVER_NAME..."
            log "\e[1;30m[CONSOLE: SERVERS] Sending STOP command to server $SERVER_NAME..."
            log "\e[1;30m[CONSOLE: SERVERS] Server $SERVER_NAME: Shutting down..."
            tmux send-keys -t "$SERVER_NAME" "stop" C-m
            sleep 6
            log "\e[1;30m[CONSOLE: SERVERS] Server $SERVER_NAME stopped..."

            loadEnvConfig $DEST
            log "\e[1;30m[CONSOLE: SERVERS] Setting server $SERVER_NAME state to \e[31mOFFLINE\e[30m..."
            curl -s --insecure "https://localhost/SERVER/php/changeServerStatus.php?server_status=OFFLINE&server_id=$SERVER_ID"

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
    ARCHIVE_DIR="/home/Minecraft/ARCHIVES/$SERVER_TYPE/"
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

    # End prompt
    echo -ne "\n\e[1;37mPress 'ENTER' to continue..."
    read PRESSED_KEY
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
                        deleteServer "$SERVER_TYPE" "$SERVER_NAME"
                    elif [[ "$ACTION" == "ARCHIVE" ]]; then
                        archiveServer "$SERVER_TYPE" "$SERVER_NAME"
                    else
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
        SERVER_PATH="/home/Minecraft/SERVERS/$SERVER_TYPE"

        local options=()
        for entry in $SERVER_PATH/*(/); do
            options+=("${entry:t} SERVER")
        done

        if ((${#options[@]} == 0)); then
            echo -e "\e[1;31mNo server folders found in $SERVER_PATH/*\e[37m"
            echo -ne "\nPress any key to return to menu..."
            read -rk1
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
    php /var/www/html/SERVER/php/setServerId.php
    SERVER_ID=$(cat /var/www/html/SERVER/.env/SERVER-ID.txt)

    configureServer "$SERVER_TYPE" "$SERVER_NAME" "$SERVER_MINECRAFT_VERSION" "$SERVER_PATH" "$SERVER_ID"

    echo -e "\e[1;30m[CONSOLE:    CREATOR] Server configuration done!\e[37m"
    echo -ne "\nPress any key to continue..."
    read -rk1
}

addServer() {
    SERVER_PATH="/home/Minecraft/SERVERS"
    local entries=()

    # Load server directories
    for entry in "$SERVER_PATH"/*; do
        [[ -d "$entry" ]] && entries+=("${entry:t}")
    done

    if ((${#entries[@]} == 0)); then
        echo -e "\e[1;31mNo server folders found in $SERVER_PATH/*\e[37m"
        echo -e "\nPress 'ENTER' to return to menu..."
        read PREDDES_KEY
        main
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

main() {
    while true; do
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
                killServerSessions
                ;;
            8)
                clear
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

# --------------------------------------------------------------------------------
# ./SERVER-MANAGER.sh --help
# --------------------------------------------------------------------------------
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    clear
    echo -e "\n\e[1;37m=====================================================================================\n"
    echo -e "                          \e[1;33mSERVER MANAGER - USAGE GUIDE\e[0m"
    echo -e "\n\e[1;37m=====================================================================================\e[0m"

    echo -e "\n\e[1;36mUsage:\e[0m \e[1;32mzsh .SERVER-MANAGER.sh [option] [server-type] [server-name]\e[0m"
    echo -e "  \e[1;30mExample:\e[0m \e[1;37mzsh .SERVER-MANAGER.sh --start-server FORGE MyServerName\e[0m"

    echo -e "\n\e[1;36mInteractive Mode:\e[0m"
    echo -e "  Run with no arguments to use interactive menu: \e[1;32mzsh .SERVER-MANAGER.sh\e[0m"

    echo -e "\n\e[1;36mAvailable Options:\e[0m"
    echo -e "  \e[1;33m--help\e[0m               Show this help message and exit"
    echo -e "  \e[1;33m--start-server\e[0m       Start the specified server"
    echo -e "  \e[1;33m--stop-server\e[0m        Stop the specified server"
    echo -e "  \e[1;33m--restart-server\e[0m     Restart the specified server"
    echo -e "  \e[1;33m--create-server\e[0m      Launch guided creation for a new server"
    echo -e "  \e[1;33m--delete-server\e[0m      Remove a server folder (requires confirmation)"
    echo -e "  \e[1;33m--archive-server\e[0m    Archieves a server folder (*.zip)"
    echo -e "  \e[1;33m--status\e[0m             Check if a server is ONLINE or OFFLINE"
    echo -e "  \e[1;33m--status-all\e[0m         Show status of all servers"
    echo -e "  \e[1;33m--list\e[0m               List all registered servers by type"

    echo -e "\n\e[1;36mArguments:\e[0m"
    echo -e "  \e[1;37m[server-type]\e[0m        Type of server: VANILLA, FORGE, MAP/PARKOUR, MAP/ESCAPE, MAP/OTHER"
    echo -e "  \e[1;37m[server-name]\e[0m        Name of the server folder"
    echo -e "  \e[1;37m[minecraft-version]\e[0m  Minecraft version to use"
    echo -e "  \e[1;37m[forge-version]\e[0m      Forge version (only for FORGE type, optional)"

    echo -e "\n\e[1;36mExamples:\e[0m"

    echo -e "  \e[0;30m[Start server]\e[0m"
    echo -e "  \e[1;37mzsh .SERVER-MANAGER.sh --start-server FORGE MyServer\e[0m"
    echo -e "  \e[1;33mzsh .SERVER-MANAGER.sh --start-server <server-type> <server-name>\e[0m"
    
    echo -e "  \e[0;30m[Stop server]\e[0m"
    echo -e "  \e[1;37mzsh .SERVER-MANAGER.sh --stop-server VANILLA TestServer\e[0m"
    echo -e "  \e[1;33mzsh .SERVER-MANAGER.sh --stop-server <server-type> <server-name>\e[0m"
    
    echo -e "  \e[0;30m[Restart server]\e[0m"
    echo -e "  \e[1;37mzsh .SERVER-MANAGER.sh --restart-server FORGE MyServer\e[0m"
    echo -e "  \e[1;33mzsh .SERVER-MANAGER.sh --restart-server <server-type> <server-name>\e[0m"

    echo -e "  \e[0;30m[Create a new server]\e[0m"
    echo -e "  \e[1;37mzsh .SERVER-MANAGER.sh --create-server FORGE MyServer 1.20.1 47.2.0\e[0m"
    echo -e "  \e[1;33mzsh .SERVER-MANAGER.sh --create-server <server-type> <server-name> <minecraft-version>  [<forge-version> --optional]\e[0m"
    
    echo -e "  \e[0;30m[Delete server]\e[0m"
    echo -e "  \e[1;37mzsh .SERVER-MANAGER.sh --delete-server VANILLA OldServer\e[0m"
    echo -e "  \e[1;33mzsh .SERVER-MANAGER.sh --delete-server <server-type> <server-name>\e[0m"

    echo -e "  \e[0;30m[Archieve server]\e[0m"
    echo -e "  \e[1;37mzsh .SERVER-MANAGER.sh --archive-server VANILLA OldServer\e[0m"
    echo -e "  \e[1;33mzsh .SERVER-MANAGER.sh --archive-server <server-type> <server-name>\e[0m"

    echo -e "  \e[0;30m[Check status of a specific server]\e[0m"
    echo -e "  \e[1;37mzsh .SERVER-MANAGER.sh --status FORGE MyServer\e[0m"
    echo -e "  \e[1;33mzsh .SERVER-MANAGER.sh --status <server-type> <server-name>\e[0m"

    echo -e "  \e[0;30m[Show statuses of all servers]\e[0m"
    echo -e "  \e[1;33mzsh .SERVER-MANAGER.sh --status-all\e[0m"

    echo -e "  \e[0;30m[Show all known servers by type]\e[0m"
    echo -e "  \e[1;33mzsh .SERVER-MANAGER.sh --list\e[0m"

    echo -e "\n\e[1;36mExpected Directory Layout:\e[0m"
    echo -e "  \e[1;33m/home/Minecraft/SERVERS/[TYPE]/[NAME]/\e[0m"
    echo -e "  \e[1;33m/home/Minecraft/SERVER/\e[0m (configs, logs, this script)"

    echo -e "\n\e[1;36mRequirements:\e[0m"
    echo -e "  \e[1;37m• tmux\e[0m"
    echo -e "  \e[1;37m• Java 8 / 17 / 21\e[0m (via update-alternatives)"
    echo -e "  \e[1;37m• curl, jq, unzip, sudo, PHP\e[0m"

    echo -e "\n\e[1;37m=====================================================================================\e[0m"
    exit 0
fi

# --------------------------------------------------------------------------------
# CLI Argument Handler with Logging
# --------------------------------------------------------------------------------
if [[ -n "$1" ]]; then
    ACTION="$1"
    SERVER_TYPE=$2
    SERVER_NAME=$3
    MINECRAFT_VERSION=$4
    SERVER_PATH=$5
    FORGE_VERSION=$6

    SERVER_ROOT="/home/Minecraft/SERVERS"
    SERVER_PATH="$SERVER_ROOT/$SERVER_TYPE/$SERVER_NAME"

    case "$ACTION" in
        --start-server)
            if [[ -z "$SERVER_TYPE" || -z "$SERVER_NAME" ]]; then
                echo -e "\e[1;31m[ERROR]\e[0m Missing server type or name. Try: \e[1;37m--start FORGE MyServer\e[0m"
                exit 1
            fi
            log "CLI: Starting server: name: --$SERVER_NAME | --type: $SERVER_TYPE."
            stopStartRestartServer START $SERVER_TYPE $SERVER_NAME
            exit 0
            ;;

        --stop-server)
            if [[ -z "$SERVER_TYPE" || -z "$SERVER_NAME" ]]; then
                echo -e "\e[1;31m[ERROR]\e[0m Missing server type or name. Try: \e[1;37m--stop FORGE MyServer\e[0m"
                exit 1
            fi
            log "CLI: Stopping server: name: --$SERVER_NAME | --type: $SERVER_TYPE."
            stopStartRestartServer STOP $SERVER_TYPE $SERVER_NAME
            exit 0
            ;;

        --restart-server)
            if [[ -z "$SERVER_TYPE" || -z "$SERVER_NAME" ]]; then
                echo -e "\e[1;31m[ERROR]\e[0m Missing server type or name. Try: \e[1;37m--restart-server FORGE MyServer\e[0m"
                exit 1
            fi
            log "CLI: Restarting server: name: --$SERVER_NAME | --type: $SERVER_TYPE."
            stopStartRestartServer RESTART $SERVER_TYPE $SERVER_NAME
            ;;

        --create-server)
            # ----------------------------------------------------------
            # Load &.env file
            # ----------------------------------------------------------
            PROPERTIES_FILE="/var/www/html/SERVER/.env/create-server-properties.env"
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
            deleteServer $SERVER_TYPE $SERVER_NAME
            exit 0
            ;;

        --archive-server)
            if [[ -z "$SERVER_TYPE" || -z "$SERVER_NAME" ]]; then
                echo -e "\e[1;31m[ERROR]\e[0m Usage: \e[1;37m--archive-server FORGE MyServer\e[0m"
                exit 1
            fi
            log "CLI: Archiving server: name: --$SERVER_NAME | --type: $SERVER_TYPE."
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
            for TYPE_PATH in /home/Minecraft/SERVERS/*(/N); do
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

            setopt null_glob
            for TYPE_PATH in /home/Minecraft/SERVERS/*(/); do
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
            unsetopt null_glob

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
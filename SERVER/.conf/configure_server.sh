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
# Ensure required Java version is installed and set
# ----------------------------------------------------------
ensureJavaVersion() {
    local MINECRAFT_VERSION="\$1"
    local JAVA_VERSION=""

    if [[ "\$MINECRAFT_VERSION" =~ ^1\\.([0-9]|1[0-6])(\\..*)?\$ ]]; then
        JAVA_VERSION="8"
    elif [[ "\$MINECRAFT_VERSION" =~ ^1\\.1[7-9](\\..*)?\$ ]]; then
        JAVA_VERSION="17"
    elif [[ "\$MINECRAFT_VERSION" =~ ^1\\.2[0-9](\\..*)?\$ ]]; then
        JAVA_VERSION="21"
    else
        echo -e "\\n\\e[1;33m[CONSOLE:  \\e[31mERROR\\e[33m] \\e[31mUnsupported or unknown Minecraft version: \$MINECRAFT_VERSION"
        exit 1
    fi

    # Check if Java is installed at all
    if ! command -v java >/dev/null 2>&1; then
        echo -e "\\n\\e[1;33m[CONSOLE: JAVA] \\e[37mJava not found. Installing OpenJDK \$JAVA_VERSION...\\e[0m"
        sudo apt update
        sudo apt install -y "openjdk-\$JAVA_VERSION-jdk"
        sudo update-alternatives --set java "/usr/lib/jvm/java-\$JAVA_VERSION-openjdk-arm64/bin/java"
        echo -e "\\n\\e[1;33m[CONSOLE: JAVA] \\e[37mJava \$JAVA_VERSION installed and set as default.\\e[0m"
        sleep 2
    else
        # Check current Java version
        local ACTIVE_JAVA_VERSION=\$(java -version 2>&1 | awk -F '"' '/version/ {print \$2}')
        ACTIVE_JAVA_VERSION="\${ACTIVE_JAVA_VERSION%%.*}"
        [[ "\$ACTIVE_JAVA_VERSION" == "1" ]] && ACTIVE_JAVA_VERSION="8"

        if [[ "\$JAVA_VERSION" != "\$ACTIVE_JAVA_VERSION" ]]; then
            # Check if required Java version is installed
            if ! dpkg -s "openjdk-\$JAVA_VERSION-jdk" >/dev/null 2>&1; then
                echo -e "\\n\\e[1;33m[CONSOLE: JAVA] \\e[37mInstalling OpenJDK \$JAVA_VERSION...\\e[0m"
                sudo apt update
                sudo apt install -y "openjdk-\$JAVA_VERSION-jdk"
                sleep 2
            fi
            echo -e "\\n\\e[1;33m[CONSOLE: JAVA] \\e[37mSwitching to Java \$JAVA_VERSION...\\e[0m"
            sudo update-alternatives --set java "/usr/lib/jvm/java-\$JAVA_VERSION-openjdk-arm64/bin/java"
        fi
    fi
}

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
ensureJavaVersion "\$MINECRAFT_VERSION"
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
# Ensure required Java version is installed and set
# ----------------------------------------------------------
ensureJavaVersion() {
    local MINECRAFT_VERSION="\$1"
    local JAVA_VERSION=""

    if [[ "\$MINECRAFT_VERSION" =~ ^1\\.([0-9]|1[0-6])(\\..*)?\$ ]]; then
        JAVA_VERSION="8"
    elif [[ "\$MINECRAFT_VERSION" =~ ^1\\.1[7-9](\\..*)?\$ ]]; then
        JAVA_VERSION="17"
    elif [[ "\$MINECRAFT_VERSION" =~ ^1\\.2[0-9](\\..*)?\$ ]]; then
        JAVA_VERSION="21"
    else
        echo -e "\\n\\e[1;33m[CONSOLE:  \\e[31mERROR\\e[33m] \\e[31mUnsupported or unknown Minecraft version: \$MINECRAFT_VERSION"
        exit 1
    fi

    # Check if Java is installed at all
    if ! command -v java >/dev/null 2>&1; then
        echo -e "\\n\\e[1;33m[CONSOLE: JAVA] \\e[37mJava not found. Installing OpenJDK \$JAVA_VERSION...\\e[0m"
        sudo apt update
        sudo apt install -y "openjdk-\$JAVA_VERSION-jdk"
        sudo update-alternatives --set java "/usr/lib/jvm/java-\$JAVA_VERSION-openjdk-arm64/bin/java"
        echo -e "\\n\\e[1;33m[CONSOLE: JAVA] \\e[37mJava \$JAVA_VERSION installed and set as default.\\e[0m"
        sleep 2
    else
        # Check current Java version
        local ACTIVE_JAVA_VERSION=\$(java -version 2>&1 | awk -F '"' '/version/ {print \$2}')
        ACTIVE_JAVA_VERSION="\${ACTIVE_JAVA_VERSION%%.*}"
        [[ "\$ACTIVE_JAVA_VERSION" == "1" ]] && ACTIVE_JAVA_VERSION="8"

        if [[ "\$JAVA_VERSION" != "\$ACTIVE_JAVA_VERSION" ]]; then
            # Check if required Java version is installed
            if ! dpkg -s "openjdk-\$JAVA_VERSION-jdk" >/dev/null 2>&1; then
                echo -e "\\n\\e[1;33m[CONSOLE: JAVA] \\e[37mInstalling OpenJDK \$JAVA_VERSION...\\e[0m"
                sudo apt update
                sudo apt install -y "openjdk-\$JAVA_VERSION-jdk"
                sleep 2
            fi
            echo -e "\\n\\e[1;33m[CONSOLE: JAVA] \\e[37mSwitching to Java \$JAVA_VERSION...\\e[0m"
            sudo update-alternatives --set java "/usr/lib/jvm/java-\$JAVA_VERSION-openjdk-arm64/bin/java"
        fi
    fi
}

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
ensureJavaVersion "\$MINECRAFT_VERSION"
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
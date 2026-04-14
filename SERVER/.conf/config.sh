# Global Variables
LOGGED_DATE=""
CURRENT_DATE=$(date '+%Y-%m-%d')
LOGGED_DAY=""
BASE_DIR="/home/Minecraft/SERVER"
CONF_DIR="$BASE_DIR/.conf"
BASE_SERVERS_DIR="/home/Minecraft/SERVERS"
BASE_ARCHIVES_DIR="/home/Minecraft/ARCHIVES"
WEB_ROOT="/var/www/html/SERVER"
WEB_URL="https://localhost/SERVER"
LOGS_DIR="$BASE_DIR/logs"
LOG_FILE="$LOGS_DIR/latest.log"
PROPERTIES_FILE="$BASE_DIR/server-properties.env"

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
# ----------------------------------------------------------
# ENV: Load values from *.env file
# ----------------------------------------------------------
loadEnvConfig() {
    local PROPERTIES_FILE="$1"
    # Load environment variables from the .env file
    # Ensure the file exists and then source it
    if [ -f "$PROPERTIES_FILE" ]; then
        source "$PROPERTIES_FILE"
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
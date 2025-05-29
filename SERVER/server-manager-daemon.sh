#!/bin/bash

# --------------------------------------------------------------------------------
# Description:  Daemon file checking file "www-server-manager-req.txt" if there
#               is a command in first line of the file & then wipes it
# Usage:        Create daemon.service || run in bg ./server-manager-daemon.sh &
# Created by:   Kaiman
# Since:        20/05/2025 (DD/MM/YYYY)
# --------------------------------------------------------------------------------
# Version:      1.0
# --------------------------------------------------------------------------------

FILE="www-server-manager-req.txt"

while true; do
    if [[ -s "$FILE" ]]; then
        # Executing first line from file
        CMD=$(sed -n '1p' "$FILE")
        echo "Executing: $CMD"
        if zsh -c "$CMD"; then
            # Wiping file
            echo "Command executed successfully. Wiping $FILE"
            : > "$FILE"
        else
            echo "Command failed, not wiping $FILE"
        fi
    fi
    sleep 2
done
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
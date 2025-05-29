#!/bin/zsh

# --------------------------------------------------------------------------------
# Description:  System and firewall manager
# Usage:        Run the file using `zsh .SysUpdate.sh`
# Created by:   Kaiman
# Since:        22/08/2024 (DD/MM/YYYY)
# --------------------------------------------------------------------------------
# Version:      2.0
# --------------------------------------------------------------------------------

# ----------------------------------------------------------
# Center text & color prompt
# ----------------------------------------------------------
center_text() {
    local text="$1"
    local line="====================================================================================="
    local line_width=${#line}
    local text_width=${#text}
    local padding=$(((line_width - text_width) / 2))

    # Print centered lines and text with colors
    printf "\e[1;37m%s\e[0m\n" "$line"                  # Top line in white
    printf "\n%*s\e[1;33m%s\e[0m\n" $padding "" "$text" # Centered text in yellow
    printf "\n\e[1;37m%s\e[0m\n" "$line"                # Bottom line in white
    printf "\n\e[1;33m"                                 # Extra newline for spacing
}

# ----------------------------------------------------------
# System update & upgrade end prompt
# ----------------------------------------------------------
sysUpdatePrompt() {
    echo "\e[1;33m"
    date "+[ DATE: %y/%m/%d | TIME: %H:%M:%S ]"
    echo -e "\n\e[1;33m[SYSTEM:   Update] \e[0;37mSystem updated!\e[0m"
    echo -e "\e[1;33m[SYSTEM:  Upgrade] \e[0;37mAll packages upgraded!\e[0m"
    echo -e "\e[1;33m[SYSTEM:  Upgrade] \e[0;37mTemp files removed...\e[0m\n"
}

# ----------------------------------------------------------
# Firewall installation & config end prompt
# ----------------------------------------------------------
firewallPrompt() {
    echo -e "\e[1;33m[SYSTEM: Firewall] \e[0;37mFirewall installed & configured!\e[0m\n"
}

# ----------------------------------------------------------
# System update & packages upgrade
# ----------------------------------------------------------
systemUpdateAndUpgrade () {
    center_text "[SYSTEM UPDATE & UPGRADE]"
    date "+[ DATE: %y/%m/%d | TIME: %H:%M:%S ]"

    echo -e "\n\e[1;33m[SYSTEM:   Update] \e[0;37mStarting system update...\e[0m\n"
    sudo apt update
    echo -e "\n\e[1;33m[SYSTEM:  Upgrade] \e[0;37mStarting system upgrade...\e[0m\n"
    sudo apt upgrade -y
    sudo apt full-upgrade -y
    echo -e "\n\e[1;33m[SYSTEM:  Upgrade] \e[0;37mRemoving temp files...\e[0m\n"
    sudo apt autoremove -y
    sudo apt autoclean

    echo -e ""
    center_text "[SYSTEM UPDATE & UPGRADE]"
    sysUpdatePrompt
    echo -e "\e[1;32mPress ENTER to return to menu...\e[0m"
    read PRESSED_KEY
}

# ----------------------------------------------------------
# Firewall installation & configuration 
# ----------------------------------------------------------
firewallInstallationAndConfig () {
    center_text "[FIREWALL CONFIG]"
    date "+[ DATE: %y/%m/%d | TIME: %H:%M:%S ]"

    echo -e "\n\e[1;33m[SYSTEM: Firewall] \e[0;37mStarting firewalld installation...\e[0m\n"
    sudo apt install firewalld -y
    sudo systemctl enable firewalld
    sudo systemctl start firewalld
    sudo firewall-cmd --state

    # Disabling default ufw firewall
    echo -e "\n\e[1;33m[SYSTEM: Firewall] \e[0;37mDisabling ufw firewall...\e[0m\n"
    sudo ufw disable

    # Enable Minecraft ports 25565/25566 tcp/udp
    echo -e "\n\e[1;33m[SYSTEM: Firewall] \e[0;37mOpening Minecraft ports 25565/25566 tcp/udp...\e[0m\n"
    sudo firewall-cmd --permanent --zone=public --add-port=25565/tcp
    sudo firewall-cmd --permanent --zone=public --add-port=25565/udp
    sudo firewall-cmd --permanent --zone=public --add-port=25566/tcp
    sudo firewall-cmd --permanent --zone=public --add-port=25566/udp

    # Enable HTTPS port
    echo -e "\n\e[1;33m[SYSTEM: Firewall] \e[0;37mOpening HTTPS port 443/tcp...\e[0m\n"
    sudo firewall-cmd --permanent --zone=public --add-port=443/tcp

    # Allow SSH (optional safety)
    echo -e "\n\e[1;33m[SYSTEM: Firewall] \e[0;37mEnsuring SSH port 22/tcp is open...\e[0m\n"
    sudo firewall-cmd --permanent --zone=public --add-port=22/tcp

    echo -e "\n\e[1;33m[SYSTEM: Firewall] \e[0;37mApplying changes to firewall...\e[0m\n"
    sudo firewall-cmd --reload
    sudo firewall-cmd --list-all
    echo -e ""
    center_text "[FIREWALL CONFIG]"
    date "+[ DATE: %y/%m/%d | TIME: %H:%M:%S ]"
    echo -e ""
    firewallPrompt
    echo -e "\e[1;32mPress ENTER to return to menu...\e[0m"
    read PRESSED_KEY
}

# ----------------------------------------------------------
# System update & upgrade + firewall installation & config 
# ----------------------------------------------------------
systemUpdateAndUpgradeWithFirewallInstallationAndConfig () {
    center_text "[SYSTEM UPDATE & FIREWALL CONFIG]"
    date "+[ DATE: %y/%m/%d | TIME: %H:%M:%S ]"

    echo -e "\n\e[1;33m[SYSTEM:   Update] \e[0;37mStarting system update...\e[0m\n"
    sudo apt update
    echo -e "\n\e[1;33m[SYSTEM:  Upgrade] \e[0;37mStarting system upgrade...\e[0m\n"
    sudo apt upgrade -y
    sudo apt full-upgrade -y
    sudo apt autoremove -y
    sudo apt autoclean

    echo -e "\n\e[1;33m[SYSTEM: Firewall] \e[0;37mStarting firewalld installation...\e[0m\n"
    sudo apt install firewalld -y
    sudo systemctl enable firewalld
    sudo systemctl start firewalld
    sudo firewall-cmd --state

    # Disabling default ufw firewall
    echo -e "\n\e[1;33m[SYSTEM: Firewall] \e[0;37mDisabling ufw firewall...\e[0m\n"
    sudo ufw disable

    # Enable Minecraft ports 25565/25566 tcp/udp
    echo -e "\n\e[1;33m[SYSTEM: Firewall] \e[0;37mOpening Minecraft ports 25565/25566 tcp/udp...\e[0m\n"
    sudo firewall-cmd --permanent --zone=public --add-port=25565/tcp
    sudo firewall-cmd --permanent --zone=public --add-port=25565/udp
    sudo firewall-cmd --permanent --zone=public --add-port=25566/tcp
    sudo firewall-cmd --permanent --zone=public --add-port=25566/udp

    # Enable HTTPS port
    echo -e "\n\e[1;33m[SYSTEM: Firewall] \e[0;37mOpening HTTPS port 443/tcp...\e[0m\n"
    sudo firewall-cmd --permanent --zone=public --add-port=443/tcp

    # Allow SSH
    echo -e "\n\e[1;33m[SYSTEM: Firewall] \e[0;37mEnsuring SSH port 22/tcp is open...\e[0m\n"
    sudo firewall-cmd --permanent --zone=public --add-port=22/tcp

    echo -e "\n\e[1;33m[SYSTEM: Firewall] \e[0;37mApplying changes to firewall...\e[0m\n"
    sudo firewall-cmd --reload
    sudo firewall-cmd --list-all

    echo -e ""
    center_text "[SYSTEM UPDATE & FIREWALL CONFIG]"
    sysUpdatePrompt
    firewallPrompt
    echo -e "\e[1;32mPress ENTER to return to menu...\e[0m"
    read PRESSED_KEY
}

# ----------------------------------------------------------
# Menu
# ----------------------------------------------------------
main() {
    while true; do
        clear
        center_text "[SYSTEM & FIREWALL MANAGER]"
        echo -e "\e[1;32m[1]\e[1;33m SYSTEM UPDATE & UPGRADE"
        echo -e "\e[1;32m[2]\e[1;33m FIREWALL INSTALLATION & CONFIG"
        echo -e "\e[1;32m[3]\e[1;33m SYSTEM UPDATE & UPGRADE + FIREWALL INSTALLATION & CONFIG"
        echo -e "\e[1;31m[Q] QUIT\e[0m"
        echo -ne "\n\e[1;33m> Select option [press key 1–3 or Q to quit]: \e[0m"
        read -rk1 PRESSED_KEY
        echo ""

        case "$PRESSED_KEY" in
            1)
                clear
                systemUpdateAndUpgrade
                ;;
            2)
                clear
                firewallInstallationAndConfig
                ;;
            3)
                clear
                systemUpdateAndUpgradeWithFirewallInstallationAndConfig
                ;;
            [qQ])
                clear
                center_text "[EXITING SYSTEM & FIREWALL MANAGER]"
                exit
                ;;
            *)
                echo -e "\n\e[1;31mInvalid option '$PRESSED_KEY'.\nPress ENTER to try again.\e[0m"
                read
                ;;
        esac
    done
}

main
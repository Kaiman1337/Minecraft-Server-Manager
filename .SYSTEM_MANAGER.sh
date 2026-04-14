#!/usr/bin/env bash

# --------------------------------------------------------------------------------
# Description:  System, firewall, Zsh & Tmux manager
# Usage:        Run the file using `bash .SYSTEM_MANAGER.sh` on first install, or `zsh .SYSTEM_MANAGER.sh` after zsh is installed
# Created by:   Kaiman
# Since:        22/08/2024 (DD/MM/YYYY)
# --------------------------------------------------------------------------------
# Version:      3.0 --Initial setup and basic system update/upgrade functions 
# Last Updated: 14/04/2026 (DD/MM/YYYY)
# --------------------------------------------------------------------------------

# Center text & color prompt
center_text() {
    local text="$1"
    local line="====================================================================================="
    local line_width=${#line}
    local text_width=${#text}
    local padding=$(((line_width - text_width) / 2))

    printf "\e[1;37m%s\e[0m\n" "$line"                  
    printf "\n%*s\e[1;33m%s\e[0m\n" $padding "" "$text" 
    printf "\n\e[1;37m%s\e[0m\n" "$line"                
    printf "\n\e[1;33m"                                 
}

# ----------------------------------------------------------
# Prompts
# ----------------------------------------------------------
sysUpdatePrompt() {
    echo -e "\e[1;33m[SYSTEM: Update] \e[0;37mSystem updated!\e[0m"
    echo -e "\e[1;33m[SYSTEM: Upgrade] \e[0;37mAll packages upgraded!\e[0m"
    echo -e "\e[1;33m[SYSTEM: Cleanup] \e[0;37mTemp files removed...\e[0m\n"
}

zshPrompt() {
    echo -e "\e[1;33m[SYSTEM: Zsh + P10k] \e[0;37mZsh & Powerlevel10k installed & configured!\e[0m\n"
    echo -e "\e[1;33m[SYSTEM: Zsh + P10k] \e[0;37mDefault shell changed to zsh!\e[0m\n"
    echo -e "\e[1;32mRestart terminal or run 'exec zsh' to use new prompt\e[0m\n"
}

tmuxPrompt() {
    echo -e "\e[1;33m[SYSTEM: Tmux] \e[0;37mTmux installed successfully!\e[0m\n"
    echo -e "\e[1;33m[SYSTEM: Tmux] \e[0;37mRun 'tmux' to start (uses default config)\e[0m\n"
}

firewallPrompt() {
    echo -e "\e[1;33m[SYSTEM: Firewall] \e[0;37mFirewall installed & configured!\e[0m\n"
}

# ----------------------------------------------------------
# System update & packages upgrade
# ----------------------------------------------------------
systemUpdateAndUpgrade() {
    center_text "[SYSTEM UPDATE & UPGRADE]"
    date "+[ DATE: %y/%m/%d | TIME: %H:%M:%S ]"

    echo -e "\n\e[1;33m[SYSTEM: Update] \e[0;37mStarting system update...\e[0m\n"
    sudo apt update
    echo -e "\n\e[1;33m[SYSTEM: Upgrade] \e[0;37mStarting system upgrade...\e[0m\n"
    sudo apt upgrade -y
    sudo apt full-upgrade -y
    echo -e "\n\e[1;33m[SYSTEM: Cleanup] \e[0;37mRemoving temp files...\e[0m\n"
    sudo apt autoremove -y
    sudo apt autoclean

    center_text "[SYSTEM UPDATE COMPLETE]"
    sysUpdatePrompt
    echo -e "\e[1;32mPress ENTER to return to menu...\e[0m"
    read PRESSED_KEY
}

installPackageIfMissing() {
    local pkg="$1"
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        echo -e "\n\e[1;33m[SYSTEM: Install] \e[0;37mInstalling missing package: $pkg...\e[0m"
        sudo apt install -y "$pkg"
    else
        echo -e "\n\e[1;33m[SYSTEM: Install] \e[0;37mPackage already installed: $pkg\e[0m"
    fi
}

# ----------------------------------------------------------
# Firewall installation & configuration 
# ----------------------------------------------------------
firewallInstallationAndConfig() {
    center_text "[FIREWALL CONFIG]"
    date "+[ DATE: %y/%m/%d | TIME: %H:%M:%S ]"

    echo -e "\n\e[1;33m[SYSTEM: Firewall] \e[0;37mStarting firewalld installation...\e[0m\n"
    sudo apt install firewalld -y
    sudo systemctl enable firewalld
    sudo systemctl start firewalld
    sudo firewall-cmd --state

    echo -e "\n\e[1;33m[SYSTEM: Firewall] \e[0;37mDisabling ufw...\e[0m\n"
    sudo ufw disable

    echo -e "\n\e[1;33m[SYSTEM: Firewall] \e[0;37mOpening Minecraft port 25565 tcp/udp...\e[0m\n"
    sudo firewall-cmd --permanent --zone=public --add-port=25565/tcp
    sudo firewall-cmd --permanent --zone=public --add-port=25565/udp

    echo -e "\n\e[1;33m[SYSTEM: Firewall] \e[0;37mOpening HTTPS port 443/tcp...\e[0m\n"
    sudo firewall-cmd --permanent --zone=public --add-port=443/tcp

    echo -e "\n\e[1;33m[SYSTEM: Firewall] \e[0;37mEnsuring SSH port 22/tcp is open...\e[0m\n"
    sudo firewall-cmd --permanent --zone=public --add-port=22/tcp

    echo -e "\n\e[1;33m[SYSTEM: Firewall] \e[0;37mApplying changes...\e[0m\n"
    sudo firewall-cmd --reload
    sudo firewall-cmd --list-all

    center_text "[FIREWALL CONFIG COMPLETE]"
    firewallPrompt
    echo -e "\e[1;32mPress ENTER to return to menu...\e[0m"
    read PRESSED_KEY
}

# ----------------------------------------------------------
# Zsh + Powerlevel10k installation & configuration
# ----------------------------------------------------------
zshInstallationAndConfig() {
    center_text "[ZSH + POWERLEVEL10K]"
    date "+[ DATE: %y/%m/%d | TIME: %H:%M:%S ]"

    echo -e "\n\e[1;33m[SYSTEM: Zsh] \e[0;37mChecking required packages: zsh, git, curl, jq...\e[0m\n"
    installPackageIfMissing zsh
    installPackageIfMissing git
    installPackageIfMissing curl
    installPackageIfMissing jq

    if [ ! -d "${ZDOTDIR:-$HOME}/.oh-my-zsh" ]; then
        echo -e "\n\e[1;33m[SYSTEM: OhMyZsh] \e[0;37mInstalling OhMyZsh...\e[0m\n"
        sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    else
        echo -e "\n\e[1;33m[SYSTEM: OhMyZsh] \e[0;37mOhMyZsh is already installed. Skipping install.\e[0m\n"
    fi

    local zsh_custom="${ZDOTDIR:-$HOME}/.oh-my-zsh/custom"
    mkdir -p "$zsh_custom/themes" "$zsh_custom/plugins"

    if [ ! -d "$zsh_custom/themes/powerlevel10k" ]; then
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$zsh_custom/themes/powerlevel10k" &>/dev/null
    fi
    if [ ! -d "$zsh_custom/plugins/zsh-autosuggestions" ]; then
        git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$zsh_custom/plugins/zsh-autosuggestions" &>/dev/null
    fi
    if [ ! -d "$zsh_custom/plugins/zsh-syntax-highlighting" ]; then
        git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$zsh_custom/plugins/zsh-syntax-highlighting" &>/dev/null
    fi

    local zshrc_file="${ZDOTDIR:-$HOME}/.zshrc"
    if [ ! -f "$zshrc_file" ]; then
        touch "$zshrc_file"
    fi

    if grep -q '^ZSH_THEME=' "$zshrc_file"; then
        sed -i 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' "$zshrc_file"
    else
        printf '\nZSH_THEME="powerlevel10k/powerlevel10k"\n' >> "$zshrc_file"
    fi

    if grep -q '^plugins=' "$zshrc_file"; then
        sed -i 's|^plugins=.*|plugins=(git zsh-autosuggestions zsh-syntax-highlighting)|' "$zshrc_file"
    else
        printf '\nplugins=(git zsh-autosuggestions zsh-syntax-highlighting)\n' >> "$zshrc_file"
    fi

    local current_shell
    current_shell=$(getent passwd "$USER" | cut -d: -f7 2>/dev/null || echo "$SHELL")
    if [[ "$current_shell" == */zsh ]]; then
        echo -e "\n\e[1;33m[SYSTEM: Zsh] \e[0;37mZsh is already the default login shell.\e[0m\n"
    else
        echo -e "\n\e[1;33m[SYSTEM: Zsh] \e[0;37mSetting Zsh as default shell...\e[0m\n"
        chsh -s "$(command -v zsh)"
    fi

    center_text "[ZSH + P10K COMPLETE]"
    zshPrompt
    echo -e "\e[1;32mPress ENTER to return to menu...\e[0m"
    read PRESSED_KEY
}

# ----------------------------------------------------------
# Tmux installation ONLY (no configuration)
# ----------------------------------------------------------
tmuxInstallationAndConfig() {
    center_text "[TMUX INSTALLATION]"
    date "+[ DATE: %y/%m/%d | TIME: %H:%M:%S ]"

    echo -e "\n\e[1;33m[SYSTEM: Tmux] \e[0;37mInstalling Tmux...\e[0m\n"
    sudo apt install tmux -y

    echo -e "\n\e[1;33m[SYSTEM: Tmux] \e[0;37mTmux installed! No config created.\e[0m\n"
    tmux -V

    center_text "[TMUX INSTALL COMPLETE]"
    tmuxPrompt
    echo -e "\e[1;32mPress ENTER to return to menu...\e[0m"
    read PRESSED_KEY
}

initializeFirstRun() {
    center_text "[INITIALIZE SYSTEM]"
    date "+[ DATE: %y/%m/%d | TIME: %H:%M:%S ]"

    echo -e "
\e[1;33m[SYSTEM: Initialize] \e[0;37mUpdating package lists...\e[0m
"
    sudo apt update

    echo -e "
\e[1;33m[SYSTEM: Initialize] \e[0;37mChecking essential packages: zsh git curl jq tmux...\e[0m
"
    installPackageIfMissing zsh
    installPackageIfMissing git
    installPackageIfMissing curl
    installPackageIfMissing jq
    installPackageIfMissing tmux

    if ! command -v jq >/dev/null 2>&1; then
        echo -e "\n\e[1;31m[SYSTEM: Initialize] ERROR: jq installation failed.\e[0m"
    fi

    zshInstallationAndConfig

    center_text "[INITIALIZE COMPLETE]"
    echo -e "\e[1;32mPress ENTER to return to menu...\e[0m"
    read PRESSED_KEY
}

# ----------------------------------------------------------
# Main menu
# ----------------------------------------------------------
main() {
    while true; do
        clear
        center_text "[SYSTEM & DEVELOPMENT MANAGER]"
        echo -e "\e[1;32m[1]\e[1;33m INITIALIZE SYSTEM (FIRST RUN)"
        echo -e "\e[1;32m[2]\e[1;33m SYSTEM UPDATE & UPGRADE"
        echo -e "\e[1;32m[3]\e[1;33m SYSTEM UPDATE + FIREWALL"
        echo -e "\e[1;31m[Q] QUIT\e[0m"
        echo -ne "\n\e[1;33m> Select option [1–3 or Q]: \e[0m"
        read -r PRESSED_KEY
        echo ""

        case "$PRESSED_KEY" in
            1) clear; initializeFirstRun ;;
            2) clear; systemUpdateAndUpgrade ;;
            3) 
                clear
                systemUpdateAndUpgrade
                firewallInstallationAndConfig 
                ;;
            [qQ])
                clear
                center_text "[EXITING MANAGER]"
                exit 0
                ;;
            *)
                echo -e "\n\e[1;31mInvalid option '$PRESSED_KEY'.\nPress ENTER to try again.\e[0m"
                read
                ;;
        esac
    done
}

main

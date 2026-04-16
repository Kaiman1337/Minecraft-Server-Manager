#!/usr/bin/env bash

# --------------------------------------------------------------------------------
# Description:  System, firewall, Zsh & Tmux manager
# Usage:        bash .SYSTEM_MANAGER.sh
# Created by:   Kaiman
# Version:      3.1
# Last Updated: 16/04/2026 (DD/MM/YYYY)
# --------------------------------------------------------------------------------

set -u

export DEBIAN_FRONTEND=noninteractive

LINE="====================================================================================="

PACKAGES=(
  zsh
  git
  curl
  jq
  tmux
  cron
  firewalld
)

# ----------------------------------------------------------
# UI
# ----------------------------------------------------------
center_text() {
    local text="$1"
    local line_width=${#LINE}
    local text_width=${#text}
    local padding=0

    if (( line_width > text_width )); then
        padding=$(( (line_width - text_width) / 2 ))
    fi

    printf "\e[1;37m%s\e[0m\n" "$LINE"
    printf "\n%*s\e[1;33m%s\e[0m\n" "$padding" "" "$text"
    printf "\n\e[1;37m%s\e[0m\n\n" "$LINE"
}

pause_return() {
    echo -e "\e[1;32mPress ENTER to return to menu...\e[0m"
    read -r
}

log_info() {
    echo -e "\e[1;33m[INFO] \e[0;37m$1\e[0m"
}

log_ok() {
    echo -e "\e[1;32m[OK] \e[0;37m$1\e[0m"
}

log_warn() {
    echo -e "\e[1;31m[WARN] \e[0;37m$1\e[0m"
}

show_date() {
    date "+[ DATE: %y/%m/%d | TIME: %H:%M:%S ]"
}

# ----------------------------------------------------------
# Helpers
# ----------------------------------------------------------
require_sudo() {
    if ! sudo -v; then
        log_warn "Sudo authentication failed."
        exit 1
    fi
}

apt_update_once() {
    log_info "Updating package lists..."
    sudo apt update
}

install_package_if_missing() {
    local pkg="$1"

    if dpkg -s "$pkg" >/dev/null 2>&1; then
        log_ok "Package already installed: $pkg"
    else
        log_info "Installing package: $pkg"
        sudo apt install -y "$pkg"
    fi
}

install_required_packages() {
    local pkg
    for pkg in "${PACKAGES[@]}"; do
        install_package_if_missing "$pkg"
    done
}

enable_service_now() {
    local service="$1"

    log_info "Enabling and starting service: $service"
    sudo systemctl enable --now "$service"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ----------------------------------------------------------
# System update & upgrade
# ----------------------------------------------------------
system_update_and_upgrade() {
    center_text "[SYSTEM UPDATE & UPGRADE]"
    show_date
    echo

    log_info "Starting system update..."
    sudo apt update

    log_info "Starting system upgrade..."
    sudo apt upgrade -y
    sudo apt full-upgrade -y

    log_info "Removing unnecessary packages..."
    sudo apt autoremove -y
    sudo apt autoclean -y

    echo
    center_text "[SYSTEM UPDATE COMPLETE]"
    log_ok "System updated and upgraded."
    pause_return
}

# ----------------------------------------------------------
# Firewall
# ----------------------------------------------------------
configure_firewalld() {
    center_text "[FIREWALL CONFIG]"
    show_date
    echo

    install_package_if_missing firewalld
    enable_service_now firewalld

    if command_exists ufw; then
        log_info "Disabling UFW to avoid conflicts..."
        sudo ufw disable || true
        sudo systemctl disable --now ufw 2>/dev/null || true
    else
        log_info "UFW not installed. Skipping."
    fi

    log_info "Opening SSH port 22/tcp..."
    sudo firewall-cmd --permanent --zone=public --add-port=22/tcp

    log_info "Opening Minecraft port 25565/tcp..."
    sudo firewall-cmd --permanent --zone=public --add-port=25565/tcp

    log_info "Opening Minecraft port 25565/udp..."
    sudo firewall-cmd --permanent --zone=public --add-port=25565/udp

    log_info "Opening HTTPS port 443/tcp..."
    sudo firewall-cmd --permanent --zone=public --add-port=443/tcp

    log_info "Reloading firewalld..."
    sudo firewall-cmd --reload

    log_info "Checking firewall state..."
    sudo firewall-cmd --state

    echo
    log_ok "Firewall installed and configured."
    sudo firewall-cmd --list-all
    echo
    center_text "[FIREWALL CONFIG COMPLETE]"
    pause_return
}

# ----------------------------------------------------------
# Zsh + Oh My Zsh + Powerlevel10k
# ----------------------------------------------------------
configure_zsh() {
    center_text "[ZSH + POWERLEVEL10K]"
    show_date
    echo

    install_package_if_missing zsh
    install_package_if_missing git
    install_package_if_missing curl
    install_package_if_missing jq

    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        log_info "Installing Oh My Zsh..."
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    else
        log_ok "Oh My Zsh already installed."
    fi

    local zsh_custom="$HOME/.oh-my-zsh/custom"
    mkdir -p "$zsh_custom/themes" "$zsh_custom/plugins"

    if [[ ! -d "$zsh_custom/themes/powerlevel10k" ]]; then
        log_info "Installing powerlevel10k..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$zsh_custom/themes/powerlevel10k"
    else
        log_ok "powerlevel10k already installed."
    fi

    if [[ ! -d "$zsh_custom/plugins/zsh-autosuggestions" ]]; then
        log_info "Installing zsh-autosuggestions..."
        git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$zsh_custom/plugins/zsh-autosuggestions"
    else
        log_ok "zsh-autosuggestions already installed."
    fi

    if [[ ! -d "$zsh_custom/plugins/zsh-syntax-highlighting" ]]; then
        log_info "Installing zsh-syntax-highlighting..."
        git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$zsh_custom/plugins/zsh-syntax-highlighting"
    else
        log_ok "zsh-syntax-highlighting already installed."
    fi

    local zshrc_file="$HOME/.zshrc"
    [[ -f "$zshrc_file" ]] || touch "$zshrc_file"

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

    local zsh_path
    zsh_path="$(command -v zsh)"

    if [[ -n "$zsh_path" ]]; then
        local current_shell
        current_shell="$(getent passwd "$USER" | cut -d: -f7)"

        if [[ "$current_shell" != "$zsh_path" ]]; then
            log_info "Setting Zsh as default shell..."
            chsh -s "$zsh_path"
        else
            log_ok "Zsh is already the default shell."
        fi
    fi

    echo
    center_text "[ZSH + POWERLEVEL10K COMPLETE]"
    log_ok "Zsh and Powerlevel10k installed and configured."
    echo -e "\e[1;32mRestart terminal or run 'exec zsh' to use new shell.\e[0m"
    pause_return
}

# ----------------------------------------------------------
# Tmux
# ----------------------------------------------------------
configure_tmux() {
    center_text "[TMUX INSTALLATION]"
    show_date
    echo

    install_package_if_missing tmux

    if command_exists tmux; then
        log_ok "Tmux installed successfully."
        tmux -V
    else
        log_warn "Tmux installation failed."
    fi

    echo
    center_text "[TMUX INSTALL COMPLETE]"
    pause_return
}

# ----------------------------------------------------------
# Cron
# ----------------------------------------------------------
configure_cron() {
    center_text "[CRON CONFIG]"
    show_date
    echo

    install_package_if_missing cron
    enable_service_now cron

    if command_exists crontab; then
        log_ok "Cron installed successfully."
        crontab -l >/dev/null 2>&1 || true
    else
        log_warn "crontab command is still unavailable."
    fi

    echo
    center_text "[CRON CONFIG COMPLETE]"
}

# ----------------------------------------------------------
# First run
# ----------------------------------------------------------
initialize_first_run() {
    center_text "[INITIALIZE SYSTEM]"
    show_date
    echo

    apt_update_once
    install_required_packages

    enable_service_now cron
    enable_service_now firewalld

    configure_cron
    configure_firewalld
    configure_tmux
    configure_zsh

    echo
    center_text "[INITIALIZE COMPLETE]"
    log_ok "First-run initialization finished."
    pause_return
}

# ----------------------------------------------------------
# Main menu
# ----------------------------------------------------------
main() {
    require_sudo

    while true; do
        clear
        center_text "[SYSTEM & DEVELOPMENT MANAGER]"
        echo -e "\e[1;32m[1]\e[1;33m INITIALIZE SYSTEM (FIRST RUN)"
        echo -e "\e[1;32m[2]\e[1;33m SYSTEM UPDATE & UPGRADE"
        echo -e "\e[1;32m[3]\e[1;33m SYSTEM UPDATE + FIREWALL"
        echo -e "\e[1;31m[Q] QUIT\e[0m"
        echo -ne "\n\e[1;33m> Select option [1–3 or Q]: \e[0m"
        read -r PRESSED_KEY
        echo

        case "$PRESSED_KEY" in
            1)
                clear
                initialize_first_run
                ;;
            2)
                clear
                system_update_and_upgrade
                ;;
            3)
                clear
                system_update_and_upgrade
                configure_firewalld
                ;;
            [qQ])
                clear
                center_text "[EXITING MANAGER]"
                exit 0
                ;;
            *)
                echo -e "\n\e[1;31mInvalid option '$PRESSED_KEY'.\nPress ENTER to try again.\e[0m"
                read -r
                ;;
        esac
    done
}

main
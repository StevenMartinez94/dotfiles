#!/bin/bash

set -euo pipefail

# Function to display messages
log() {
    echo -e "\033[1;32m[+] $1\033[0m"
}

# Function to check if the script is run as root
check_not_root() {
    if [ "$EUID" -eq 0 ]; then
        echo "Please do not run this script as root. It will use sudo when necessary."
        exit 1
    fi
}

# Function to create user directories
create_user_dirs() {
    log "Creating user directories..."
    for dir in Downloads "Pictures/Wallpapers" "Pictures/Screenshots" Documents Projects Videos; do
        if [ ! -d "$HOME/$dir" ]; then
            mkdir -p "$HOME/$dir"
            log "Created: $dir"
        else
            log "Exists: $dir"
        fi
    done
}

# Function to install pacman packages
install_pacman_packages() {
    log "Updating system and installing pacman packages..."
    sudo pacman -Syu --noconfirm
    sudo pacman -S --needed --noconfirm \
        speedtest-cli jq fastfetch unzip neovim git gcc hyprland kitty ranger wget zsh \
        base-devel bluez bluez-utils bpytop tree docker docker-compose python-pip pyenv \
        less websocat nodejs npm brightnessctl pavucontrol openssh sddm pacman-contrib \
        xdg-desktop-portal-hyprland xdg-desktop-portal-gtk obs-studio
}

# Function to add user to docker group
add_user_to_docker_group() {
    log "Adding user to docker group..."
    sudo usermod -aG docker "$USER"
}

# Function to enable and start services
enable_services() {
    log "Enabling and starting services..."
    for service in docker.service docker.socket containerd.service bluetooth.service; do
        sudo systemctl enable "$service"
        sudo systemctl start "$service"
    done
}

# Function to install yay
install_yay() {
    if ! command -v yay &>/dev/null; then
        log "Installing yay AUR helper..."
        temp_dir=$(mktemp -d)
        git clone https://aur.archlinux.org/yay.git "$temp_dir/yay"
        (cd "$temp_dir/yay" && makepkg -si --noconfirm)
        rm -rf "$temp_dir"
    else
        log "yay is already installed."
    fi
}

# Function to install AUR packages using yay
install_yay_packages() {
    log "Installing AUR packages with yay..."
    yay -S --needed --noconfirm \
        gowall waybar cursor-bin wofi grpcurl google-chrome hyprpaper hyprpicker \
        hyprshot hyprlock hypridle nwg-look spotify-player \
        ttf-cascadia-code-nerd ttf-font-awesome ttf-joypixels nerd-fonts-complete
}

# Function to install oh-my-zsh
install_oh_my_zsh() {
    log "Installing oh-my-zsh..."
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    else
        log "oh-my-zsh is already installed."
    fi
}

# Function to change default shell to zsh
change_default_shell() {
    log "Changing default shell to zsh..."
    chsh -s "$(which zsh)"
}

# Function to synchronize system time
sync_time() {
    log "Synchronizing system time..."
    sudo timedatectl set-ntp true
}

# Main function to orchestrate the setup
main() {
    check_not_root
    create_user_dirs
    install_pacman_packages
    add_user_to_docker_group
    enable_services
    install_yay
    install_yay_packages
    install_oh_my_zsh
    change_default_shell
    sync_time
    log "Setup complete!"
}

# Execute the main function
main

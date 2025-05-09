#!/bin/sh

set -e
set -o pipefail

log() {
    echo "[+] $1"
}

die() {
    echo "[!] $1" >&2
    exit 1
}

create_user_dirs() {
    log "Creating user's basic filesystem..."
    for dir in Downloads "Pictures/Wallpapers" "Pictures/Screenshots" Documents Projects Videos; do
        [ -d "$HOME/$dir" ] || mkdir -p "$HOME/$dir" && log "    Created: $dir"
    done
}

install_pacman_packages() {
    log "Updating system and installing pacman packages..."
    sudo pacman -Syu --noconfirm
    sudo pacman -S --needed --noconfirm \
        speedtest-cli jq fastfetch unzip neovim git gcc hyprland kitty ranger wget zsh \
        base-devel ttf-cascadia-code ttf-font-awesome noto-fonts-cjk ttf-joypixels nerd-fonts \
        bluez bluez-utils bpytop tree docker docker-compose python-pip python-pienv \
        less websocat nodejs npm brightnessctl pavucontrol openssh sddm pacman-contrib \
        xdg-desktop-portal-hyprland xdg-desktop-portal-gtk obs-studio
}

configure_docker() {
    log "Adding user to docker group and enabling services..."
    sudo usermod -aG docker "$USER"

    for service in docker.service docker.socket containerd.service bluetooth.service; do
        sudo systemctl enable "$service"
        sudo systemctl start "$service"
    done
}

install_yay() {
    log "Checking if yay is installed..."
    if ! command -v yay > /dev/null 2>&1; then
        log "    Installing yay..."
        temp_dir=$(mktemp -d)
        git clone https://aur.archlinux.org/yay.git "$temp_dir/yay"
        (cd "$temp_dir/yay" && makepkg -si --noconfirm)
        rm -rf "$temp_dir"
    else
        log "    yay already installed."
    fi
}

install_aur_packages() {
    log "Installing AUR packages with yay..."
    yay -S --needed --noconfirm \
        gowall waybar cursor-bin wofi grpcurl google-chrome hyprpaper \
        hyprpicker hyprshot hyprlock hypridle nwg-look spotify-player
}

install_ohmyzsh() {
    log "Installing oh-my-zsh..."
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    else
        log "    oh-my-zsh already installed."
    fi

    log "Changing default shell to zsh..."
    chsh -s "$(which zsh)"
}

sync_time() {
    log "Syncing system time..."
    sudo timedatectl set-ntp true
}

main() {
    create_user_dirs
    install_pacman_packages
    configure_docker
    install_yay
    install_aur_packages
    install_ohmyzsh
    sync_time

    log "Setup complete!"
}

main

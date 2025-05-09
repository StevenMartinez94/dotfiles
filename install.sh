#!/bin/bash

set -euo pipefail

log() {
    local type="$1"; shift
    case "$type" in
        info)
            echo -e "\033[1;32m[INFO] $*\033[0m" ;;     # Bright green
        warn)
            echo -e "\033[1;33m[WARN] $*\033[0m" ;;     # Bright yellow
        error)
            echo -e "\033[1;31m[ERROR] $*\033[0m" ;;    # Bright red
        *)
            echo -e "\033[1;34m[LOG] $*\033[0m" ;;      # Bright blue (default)
    esac
}

check_not_root() {
    if [ "$EUID" -eq 0 ]; then
        log error "Please do not run this script as root. It will use sudo when necessary."
        exit 1
    fi
}

create_user_dirs() {
    log info "Creating user directories..."
    for dir in Downloads "Pictures/Wallpapers" "Pictures/Screenshots" Documents Projects Videos; do
        if [ ! -d "$HOME/$dir" ]; then
            mkdir -p "$HOME/$dir"
            log info "Created: $dir"
        else
            log warn "Already exists: $dir"
        fi
    done
}

install_pacman_packages() {
    log info "Updating system and installing pacman packages..."
    sudo pacman -Syu --noconfirm
    sudo pacman -S --needed --noconfirm \
        speedtest-cli jq fastfetch unzip neovim git gcc hyprland kitty ranger wget zsh \
        base-devel bluez bluez-utils bpytop tree docker docker-compose python-pip pyenv \
        less websocat nodejs npm brightnessctl pavucontrol openssh sddm pacman-contrib \
        xdg-desktop-portal-hyprland xdg-desktop-portal-gtk obs-studio
}

add_user_to_docker_group() {
    log info "Adding user to docker group..."
    sudo usermod -aG docker "$USER"
}

enable_services() {
    log info "Enabling and starting services..."
    for service in docker.service docker.socket containerd.service bluetooth.service; do
        sudo systemctl enable "$service"
        sudo systemctl start "$service"
        log info "Service enabled: $service"
    done
}

install_yay() {
    if ! command -v yay &>/dev/null; then
        log info "Installing yay AUR helper..."
        temp_dir=$(mktemp -d)
        git clone https://aur.archlinux.org/yay.git "$temp_dir/yay"
        (cd "$temp_dir/yay" && makepkg -si --noconfirm)
        rm -rf "$temp_dir"
        log info "yay installed successfully."
    else
        log warn "yay already installed. Skipping."
    fi
}

install_yay_packages() {
    log info "Installing AUR packages with yay..."
    yay -S --needed --noconfirm \
        gowall waybar cursor-bin wofi grpcurl google-chrome hyprpaper hyprpicker \
        hyprshot hyprlock hypridle nwg-look spotify-player \
        ttf-cascadia-code-nerd ttf-font-awesome ttf-joypixels nerd-fonts-complete
}

install_oh_my_zsh() {
    log info "Installing oh-my-zsh..."
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        log info "oh-my-zsh installed without launching shell."
    else
        log warn "oh-my-zsh already installed. Skipping."
    fi
}

change_default_shell() {
    log info "Changing default shell to zsh..."
    chsh -s "$(which zsh)"
}

sync_time() {
    log info "Synchronizing system time..."
    sudo timedatectl set-ntp true
}

cleanup_shell_files() {
    log info "Cleaning up bash-related and shell backup files..."

    # Remove .bash* files
    for file in "$HOME"/.bash*; do
        [ -e "$file" ] || continue
        rm -f "$file"
        log info "Removed: $(basename "$file")"
    done

    # Remove .shell.pre-oh-my-zsh
    if [ -f "$HOME/.shell.pre-oh-my-zsh" ]; then
        rm -f "$HOME/.shell.pre-oh-my-zsh"
        log info "Removed: .shell.pre-oh-my-zsh"
    fi
}

configure_bluetooth_fastconnectable() {
    log info "Configuring Bluetooth: setting FastConnectable=true..."
    local config="/etc/bluetooth/main.conf"
    
    sudo sed -i 's/^#*FastConnectable=.*/FastConnectable=true/' "$config"

    if ! grep -q '^FastConnectable=' "$config"; then
        echo "FastConnectable=true" | sudo tee -a "$config" > /dev/null
        log info "Added FastConnectable=true to $config"
    else
        log info "Updated FastConnectable=true in $config"
    fi
}


# --------------------------------------
# Main execution
# --------------------------------------
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
    cleanup_shell_files
    sync_time
    configure_bluetooth_fastconnectable
    log info "Setup complete!"
}

main

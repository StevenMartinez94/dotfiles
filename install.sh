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

add_user_to_docker_group() {
    log info "Adding user to docker group..."
    sudo usermod -aG docker "$USER"
}

enable_docker_service() {
    log info "Enabling and starting docker service..."
    sudo systemctl enable --now docker.service
}

install_yay() {
    if ! command -v yay &>/dev/null; then
        log info "Installing yay AUR helper..."
        temp_dir=$(mktemp -d)
        sudo pacman -S --needed git base-devel
        git clone https://aur.archlinux.org/yay-bin.git "$temp_dir/yay"
        (cd "$temp_dir/yay" && makepkg -si --noconfirm)
        rm -rf "$temp_dir"
        log info "yay installed successfully."
    else
        log warn "yay already installed. Skipping."
    fi
}

install_yay_packages() {
    log info "Installing AUR packages with yay..."
    yay -Syuu --noconfirm
    yay -S --needed --noconfirm \
        speedtest-cli fastfetch nerdfetch unzip gcc hyprland kitty yazi zsh \
        bluez bluez-utils bpytop tree swaync qt5-wayland qt6-wayland \
        less brightnessctl pavucontrol pacman-contrib awww udiskie matugen-bin \
        xdg-desktop-portal-hyprland xdg-desktop-portal-gtk obs-studio noto-fonts noto-fonts-cjk \
        ttf-cascadia-code ttf-cascadia-code-nerd ttf-font-awesome noto-fonts-emoji otf-departure-mono-nerd \
        ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-victor-mono rofi-wayland waybar \
	    hyprshot hyprlock hypridle nwg-look google-chrome polkit-gnome gnome-keyring kvantum ttf-meslo-nerd \
	    power-profiles-daemon claude-desktop wlogout ttf-geist-mono papirus-icon-theme papirus-folders \
	    github-cli flutter-bin android-studio insomnia-bin
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

install_zsh_plugins() {
    log info "Installing Zsh plugins: syntax highlighting and autosuggestions..."

    local custom_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    # zsh-syntax-highlighting
    if [ ! -d "$custom_dir/plugins/zsh-syntax-highlighting" ]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$custom_dir/plugins/zsh-syntax-highlighting"
        log info "Installed zsh-syntax-highlighting"
    else
        log warn "zsh-syntax-highlighting already installed"
    fi

    # zsh-autosuggestions
    if [ ! -d "$custom_dir/plugins/zsh-autosuggestions" ]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions "$custom_dir/plugins/zsh-autosuggestions"
        log info "Installed zsh-autosuggestions"
    else
        log warn "zsh-autosuggestions already installed"
    fi
    # Copying custom .zshrc file
    cp "./.zshrc" "$HOME/.zshrc"
    log info "Copied custom .zshrc to $HOME/.zshrc"
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

setup_config() {
    local name="$1"
    local source_config="./.config/$name"
    local destination_config="$HOME/.config/$name"

    log info "Setting up $name configuration..."

    if [ ! -d "$source_config" ]; then
        log error "Source directory $source_config does not exist"
        return 1
    fi

    mkdir -p "$destination_config"
    cp -r "$source_config"/. "$destination_config/"
    log info "$name configuration copied to $destination_config"
}

setup_matugen_config() {
    setup_config matugen
    chmod +x "$HOME/.config/matugen"/post-hook-scripts/*.sh 2>/dev/null || true
}

# --------------------------------------
# Main execution
# --------------------------------------
main() {
    check_not_root
    create_user_dirs
    install_yay
    install_yay_packages
    install_oh_my_zsh
    change_default_shell
    install_zsh_plugins
    cleanup_shell_files
    sync_time
    configure_bluetooth_fastconnectable
    setup_config hypr
    setup_config waybar
    setup_config kitty
    setup_config gtk-3.0
    setup_config gtk-4.0
    setup_config rofi
    setup_matugen_config
    setup_config wlogout
    log info "Setup complete!, now enabling services and starting them..."
    enable_docker_service
    add_user_to_docker_group
}

main

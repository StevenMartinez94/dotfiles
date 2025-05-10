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
        gowall waybar cursor-bin ulauncher grpcurl google-chrome hyprpaper hyprpicker \
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
# Theme setup
# --------------------------------------
setup_waybar_catppuccin_theme() {
    log info "Setting up Catppuccin Mocha theme for Waybar..."

    local waybar_config="$HOME/.config/waybar"
    local themes_dir="$waybar_config/themes"
    local theme_url="https://raw.githubusercontent.com/catppuccin/waybar/main/themes/mocha.css"
    local target_css="$themes_dir/mocha.css"
    local symlink="$waybar_config/style.css"

    mkdir -p "$themes_dir"

    # Download Mocha flavor CSS
    curl -fsSL "$theme_url" -o "$target_css"
    log info "Downloaded Catppuccin Mocha CSS."

    # Backup existing style.css if it exists and is not already the desired symlink
    if [ -f "$symlink" ] && [ ! -L "$symlink" ]; then
        mv "$symlink" "$symlink.backup"
        log warn "Backed up existing style.css to style.css.backup"
    fi

    # Link mocha theme to style.css
    ln -sf "$target_css" "$symlink"
    log info "Linked $target_css to $symlink"
}

setup_ranger_dracula_theme() {
    log info "Setting up Dracula theme for Ranger..."

    local ranger_config="$HOME/.config/ranger"
    local theme_url="https://raw.githubusercontent.com/dracula/ranger/master/dracula.py"
    local theme_dest="$ranger_config/colorschemes/dracula.py"
    local rc_file="$ranger_config/rc.conf"

    # Ensure ranger config files are initialized
    if [ ! -f "$rc_file" ]; then
        ranger --copy-config=all
        log info "Copied default ranger configuration files."
    fi

    # Download Dracula theme file
    curl -fsSL "$theme_url" -o "$theme_dest"
    log info "Downloaded Dracula theme to $theme_dest"

    # Ensure rc.conf includes the theme
    if ! grep -q 'set colorscheme dracula' "$rc_file" 2>/dev/null; then
        echo 'set colorscheme dracula' >> "$rc_file"
        log info "Set Dracula as Ranger's colorscheme in rc.conf"
    else
        log warn "Ranger rc.conf already references Dracula"
    fi
}

setup_kitty_catppuccin_theme() {
    log info "Setting up Catppuccin Mocha theme for Kitty..."

    local kitty_config="$HOME/.config/kitty"
    local theme_url="https://raw.githubusercontent.com/catppuccin/kitty/main/themes/mocha.conf"
    local theme_file="$kitty_config/mocha.conf"
    local main_conf="$kitty_config/kitty.conf"

    mkdir -p "$kitty_config"
    curl -fsSL "$theme_url" -o "$theme_file"
    log info "Downloaded Mocha theme for Kitty."

    # Ensure main kitty.conf includes the theme
    if ! grep -q "include mocha.conf" "$main_conf" 2>/dev/null; then
        echo "include mocha.conf" >> "$main_conf"
        log info "Appended theme include to kitty.conf"
    else
        log warn "kitty.conf already includes mocha.conf"
    fi
}

setup_gtk3_catppuccin_theme() {
    log info "Installing Catppuccin Mocha GTK theme (lavender) via AUR..."

    # Install AUR GTK theme variant with lavender accent
    yay -S --needed --noconfirm catppuccin-gtk-theme-mocha

    # Apply theme using settings.ini (no Gnome/gsettings)
    local gtk_dir="$HOME/.config/gtk-3.0"
    mkdir -p "$gtk_dir"
    cat > "$gtk_dir/settings.ini" <<EOF
[Settings]
gtk-theme-name=Catppuccin-Mocha-Lavender
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Noto Sans 10
EOF

    log info "Configured GTK 3 theme via ~/.config/gtk-3.0/settings.ini"
}

setup_ulauncher_catppuccin_theme() {
    log info "Setting up Catppuccin Mocha theme for Ulauncher"

    # Run the official installation script
    if command -v python3 >/dev/null 2>&1; then
        python3 <(curl https://raw.githubusercontent.com/catppuccin/ulauncher/main/install.py -fsSL) --flavor mocha --accent lavender
        log info "Catppuccin Ulauncher theme installed successfully."
    else
        log error "Python 3 is not installed. Cannot install Ulauncher theme."
    fi
}

setup_nvim_catppuccin_theme() {
    log info "Installing Catppuccin Mocha theme for Neovim..."

    local nvim_config="$HOME/.config/nvim"
    local theme_repo="https://github.com/catppuccin/nvim.git"
    local theme_temp="$(mktemp -d)"
    local theme_dest="$nvim_config/pack/plugins/start/catppuccin.nvim"

    mkdir -p "$nvim_config/pack/plugins/start"
    git clone --depth=1 "$theme_repo" "$theme_temp"
    mv "$theme_temp" "$theme_dest"
    log info "Cloned catppuccin.nvim into $theme_dest"

    # Add Catppuccin theme setup to init.lua
    local init_file="$nvim_config/init.lua"
    if [ ! -f "$init_file" ]; then
        touch "$init_file"
    fi

    if ! grep -q 'catppuccin' "$init_file"; then
        cat >> "$init_file" <<EOF

-- Catppuccin Mocha (Lavender) theme setup
vim.cmd.colorscheme "catppuccin"
require("catppuccin").setup {
    flavour = "mocha",
    integrations = {
        nvimtree = true,
        treesitter = true,
        telescope = true,
    }
}
EOF
        log info "Appended Catppuccin setup to init.lua"
    else
        log warn "init.lua already contains Catppuccin configuration"
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
    setup_waybar_catppuccin_theme
    setup_ranger_catppuccin_theme
    setup_kitty_catppuccin_theme
    setup_gtk3_catppuccin_theme
    setup_ulauncher_catppuccin_theme
    log info "Setup complete!"
}

main

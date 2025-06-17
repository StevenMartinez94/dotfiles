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
    for service in docker.service docker.socket containerd.service bluetooth.service sddm.service; do
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
        gowall waybar cursor-bin rofi-lbonn-wayland-git grpcurl google-chrome hyprpaper hyprpicker \
        hyprshot hyprlock hypridle nwg-look ncspot papirus-icon-theme paru sddm-theme-corners-git \
        ttf-cascadia-code-nerd ttf-font-awesome ttf-joypixels nerd-fonts-complete noto-fons
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

configure_sddm_theme() {
    log info "Configuring SDDM with Corners theme..."
    
    # Create SDDM themes directory if it doesn't exist
    sudo mkdir -p /usr/share/sddm/themes/corners/
    
    # Copy the theme configuration file
    if [ -f "./ssdm/theme.conf" ]; then
        sudo cp "./ssdm/theme.conf" "/usr/share/sddm/themes/corners/theme.conf"
        log info "SDDM theme configuration copied to /usr/share/sddm/themes/corners/theme.conf"
    else
        log error "theme.conf not found in ./ssdm directory"
        return 1
    fi

    # Create or ensure SDDM config directory exists
    sudo mkdir -p /usr/lib/sddm/sddm.conf.d/
    CONFIG_FILE="/usr/lib/sddm/sddm.conf.d/default.conf"

    # Create the file if it doesn't exist
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "[Theme]\nCurrent=corners" | sudo tee "$CONFIG_FILE" > /dev/null
    else
        # Check if [Theme] section exists
        if grep -q "^\[Theme\]" "$CONFIG_FILE"; then
            # If section exists, update or append the Current setting
            if grep -q "^\[Theme\]" "$CONFIG_FILE" && grep -A 5 "^\[Theme\]" "$CONFIG_FILE" | grep -q "^Current="; then
                # Replace existing Current line under [Theme]
                sudo sed -i '/^\[Theme\]/,/^\[.*\]/ s/^Current=.*/Current=corners/' "$CONFIG_FILE"
            else
                # Add Current=corners under existing [Theme] section
                sudo sed -i '/^\[Theme\]/a Current=corners' "$CONFIG_FILE"
            fi
        else
            # Add new [Theme] section at the end
            echo -e "\n[Theme]\nCurrent=corners" | sudo tee -a "$CONFIG_FILE" > /dev/null
        fi
    fi

    log info "SDDM theme configured to use Corners theme"
}

setup_hyprland_config() {
    log info "Setting up hyrpland.conf file..."
    
    # Create Hyprland config directory if it doesn't exist
    mkdir -p "$HOME/.config/hypr"
    
    # Copy the configuration file from .config directory
    if [ -f ".config/hyprland.conf" ]; then
        cp ".config/hyprland.conf" "$HOME/.config/hypr/hyprland.conf"
        log info "Hyprland configuration copied to $HOME/.config/hypr/hyprland.conf"
    else
        log error "hyprland.conf not found in .config directory"
    fi
}

# --------------------------------------
# Theme setup
# --------------------------------------
setup_waybar_theme() {
    log info "Setting up custom Waybar configuration..."

    local waybar_config="$HOME/.config/waybar"
    local source_config=".config/waybar"

    # Check if source directory exists
    if [ ! -d "$source_config" ]; then
        log error "Source directory $source_config does not exist"
        return 1
    fi

    # Create destination directory if it doesn't exist
    mkdir -p "$waybar_config"

    # Copy all files from source to destination
    cp -r "$source_config"/* "$waybar_config/"
    log info "Copied all Waybar configuration files to $waybar_config"
}

setup_ranger_theme() {
    log info "Setting up custom Ranger configuration..."

    local ranger_config="$HOME/.config/ranger"
    local source_config=".config/ranger"

    # Check if source directory exists
    if [ ! -d "$source_config" ]; then
        log error "Source directory $source_config does not exist"
        return 1
    fi

    # Create destination directory if it doesn't exist
    mkdir -p "$ranger_config"

    # Copy all files from source to destination
    cp -r "$source_config"/* "$ranger_config/"
    log info "Copied all Ranger configuration files to $ranger_config"
}

setup_kitty_theme() {
    log info "Setting up Catppuccin Mocha theme for Kitty..."

    local kitty_config="$HOME/.config/kitty"
    local theme_url="https://raw.githubusercontent.com/catppuccin/kitty/main/themes/mocha.conf"
    local theme_file="$kitty_config/mocha.conf"
    local main_conf="$kitty_config/kitty.conf"

    mkdir -p "$kitty_config"
    curl -fsSL "$theme_url" -o "$theme_file"
    log info "Downloaded Mocha theme for Kitty."

    # Ensure main kitty.conf includes the theme and sets the font
    if ! grep -q "include mocha.conf" "$main_conf" 2>/dev/null; then
        echo "include mocha.conf" >> "$main_conf"
        log info "Appended theme include to kitty.conf"
    else
        log warn "kitty.conf already includes mocha.conf"
    fi

    if ! grep -qi "^font_family" "$main_conf" 2>/dev/null; then
        echo "font_family Cascadia Code" >> "$main_conf"
        log info "Set font to Cascadia Code in kitty.conf"
    else
        log warn "kitty.conf already defines a font_family"
    fi
}

setup_gtk3_theme() {
    log info "Setting up custom GTK3 configuration..."

    local gtk_config="$HOME/.config/gtk-3.0"
    local source_config=".config/gtk-3.0"

    # Check if source directory exists
    if [ ! -d "$source_config" ]; then
        log error "Source directory $source_config does not exist"
        return 1
    fi

    # Create destination directory if it doesn't exist
    mkdir -p "$gtk_config"

    # Copy all files from source to destination
    cp -r "$source_config"/* "$gtk_config/"
    log info "Copied all GTK3 configuration files to $gtk_config"
}

setup_rofi_theme() {
    log info "Setting up custom Rofi configuration..."

    local rofi_config="$HOME/.config/rofi"
    local source_config=".config/rofi"

    # Check if source directory exists
    if [ ! -d "$source_config" ]; then
        log error "Source directory $source_config does not exist"
        return 1
    fi

    # Create destination directory if it doesn't exist
    mkdir -p "$rofi_config"

    # Copy all files from source to destination
    cp -r "$source_config"/* "$rofi_config/"
    log info "Copied all Rofi configuration files to $rofi_config"
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
    install_yay
    install_yay_packages
    install_oh_my_zsh
    change_default_shell
    install_zsh_plugins
    cleanup_shell_files
    sync_time
    configure_bluetooth_fastconnectable
    configure_sddm_theme
    setup_hyprland_config
    setup_waybar_theme
    setup_ranger_theme
    setup_kitty_theme
    setup_gtk3_theme
    setup_rofi_theme
    setup_nvim_catppuccin_theme
    log info "Setup complete!, now enabling services and starting them..."
    enable_services
}

main

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
    
    # Create SDDM config directory if it doesn't exist
    sudo mkdir -p /etc/sddm.conf.d/
    
    # Create or update the theme configuration
    cat << EOF | sudo tee /etc/sddm.conf.d/theme.conf
[Theme]
Current=corners
EOF
    
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

    # Create colorschemes directory if it doesn't exist
    mkdir -p "$ranger_config/colorschemes"
    log info "Ensured colorschemes directory exists"

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

setup_rofi_catppuccin_theme() {
    log info "Setting up Catppuccin Mocha theme for Rofi (Wayland)..."

    local rofi_config="$HOME/.config/rofi"
    local theme_dir="$rofi_config/themes"
    local theme_url="https://raw.githubusercontent.com/catppuccin/rofi/main/themes/catppuccin-mocha.rasi"
    local theme_file="$theme_dir/catppuccin-mocha.rasi"
    local config_file="$rofi_config/config.rasi"

    mkdir -p "$theme_dir"
    curl -fsSL "$theme_url" -o "$theme_file"
    log info "Downloaded Catppuccin Mocha theme for Rofi."

    # Set theme in config.rasi
    if [ ! -f "$config_file" ]; then
        echo "@theme \"catppuccin-mocha\"" > "$config_file"
        log info "Created config.rasi and set theme."
    elif ! grep -q '@theme "catppuccin-mocha"' "$config_file"; then
        echo "@theme \"catppuccin-mocha\"" >> "$config_file"
        log info "Appended theme to config.rasi"
    else
        log warn "config.rasi already sets catppuccin-mocha theme"
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
    setup_waybar_catppuccin_theme
    setup_ranger_dracula_theme
    setup_kitty_catppuccin_theme
    setup_gtk3_catppuccin_theme
    setup_rofi_catppuccin_theme
    setup_nvim_catppuccin_theme
    log info "Setup complete!, now enabling services and starting them..."
    enable_services
}

main

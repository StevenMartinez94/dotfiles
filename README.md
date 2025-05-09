# Dotfiles

My personal dotfiles and system configuration for Arch Linux with Hyprland.

## Overview

This repository contains my system configuration, including:
- Hyprland window manager setup
- Development tools and utilities
- System configuration
- User directory structure
- Package management (pacman and AUR)

## Prerequisites

- Arch Linux
- Internet connection
- Non-root user with sudo privileges

## Installation

1. Clone this repository:
```bash
git clone https://github.com/stevenmartinez94/dotfiles.git
cd dotfiles
```

2. Make the install script executable:
```bash
chmod +x install.sh
```

3. Run the installation script:
```bash
./install.sh
```

## What's Included

### System Packages
- Development tools (gcc, base-devel)
- Version control (git)
- Terminal emulator (kitty)
- File manager (ranger)
- System monitoring (bpytop)
- Docker and Docker Compose
- Node.js and npm
- Various utilities (speedtest-cli, jq, fastfetch, etc.)

### AUR Packages
- yay (AUR helper)
- gowall
- waybar
- wofi
- Google Chrome
- Hyprland-related tools (hyprpaper, hyprpicker, hyprshot, hyprlock, hypridle)
- Fonts (Cascadia Code Nerd, Font Awesome, JoyPixels)

### Shell Configuration
- zsh with oh-my-zsh
- Custom shell configurations

### Services
- Docker
- Bluetooth
- SSH

### User Directories
Creates standard user directories:
- Downloads
- Pictures/Wallpapers
- Pictures/Screenshots
- Documents
- Projects
- Videos

## Features

- Automatic system updates
- Docker group configuration
- Bluetooth fast connectable mode
- System time synchronization
- Clean shell configuration
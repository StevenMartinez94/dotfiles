#!/bin/sh

# Creting basic user's filesystem
mkdir -p Downloads Pictures/Wallpapers Pictures/Screenshots Documents Projects Videos

# Installing pacman packages
pacman -S \
	speedtest-cli jq fastfetch unzip neovim git gcc hyprland kitty ranger wget zsh \
	base-devel ttf-cascadia-code ttf-font-awesome noto-fonts-cjk ttf-joypixels nerd-fonts \
	bluez bluez-utils bpytop tree docker docker-compose python-pip python-pienv \
	websocat nodejs npm brightnessctl pavucontrol openssh sddm pacman-contrib \
	xdg-desktop-portal-hyprland xdg-desktop-portal-gtk obs-studio --noconfirm

sudo usermod -aG docker $USER

# TODO add SSH config

# Enabling services
sudo systemctl enable docker.service
sudo systemctl start docker.service
sudo systemctl enable docker.socket
sudo systemctl enable containerd.service
sudo systemctl enable bluetooth.service

# Installing yay
git clone https://aur.archlinux.org/yay.git
cd yay && makepkg -si

# Installing yay packages
yay -S gowall waybar cursor-bin wofi grpcurl google-chrome hyprpaper hyprpicker hyprshot hyprlock hypridle nwg-look spotify-player --noconfirm

# Installing ohmyzsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
chsh -s $(which zsh)

sudo timedatectl set-ntp true



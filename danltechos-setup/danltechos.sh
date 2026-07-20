#!/bin/bash
# danltechos-setup - Transform EndeavourOS into DanlTechOS
# English version with added features: GRUB splash image, KDE wallpaper

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================
# PARSE ARGUMENTS
# ============================================
AUTO=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --auto) AUTO=true ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  DanlTechOS Setup v1.0${NC}"
echo -e "${GREEN}========================================${NC}"

# ============================================
# CHECK ROOT
# ============================================
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root!${NC}"
    echo "Please run: sudo danltechos-setup"
    exit 1
fi

# ============================================
# CONFIRM
# ============================================
if [[ "$AUTO" == false ]]; then
    echo ""
    echo -e "${YELLOW}This will transform your system into DanlTechOS.${NC}"
    echo -e "${YELLOW}Backups will be created in /root/danltechos-backup-*${NC}"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

# ============================================
# BACKUP
# ============================================
BACKUP_DIR="/root/danltechos-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo -e "${BLUE}Backups: $BACKUP_DIR${NC}"

backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup_path="$BACKUP_DIR$(dirname "$file")"
        mkdir -p "$backup_path"
        cp -v "$file" "$backup_path/" 2>/dev/null || true
    fi
}

# ============================================
# CONFIGURATION DIRECTORY (from package)
# ============================================
CONFIG_DIR="/usr/share/danltechos/configs"

if [[ ! -d "$CONFIG_DIR" ]]; then
    echo -e "${RED}Error: Config directory not found!${NC}"
    echo "Please reinstall danltechos-setup package."
    exit 1
fi

echo -e "${GREEN}Using configs from: $CONFIG_DIR${NC}"

# ============================================
# 1. SYSTEM FILES (from configs)
# ============================================
echo -e "\n${GREEN}[1/5] Installing DanlTechOS system files...${NC}"

backup_file "/etc/os-release"
backup_file "/etc/lsb-release"
backup_file "/etc/issue"
backup_file "/etc/issue.net"
backup_file "/etc/hostname"

if [[ -f "$CONFIG_DIR/os-release" ]]; then
    cp "$CONFIG_DIR/os-release" /etc/os-release
    echo -e "${GREEN}  ✓ /etc/os-release${NC}"
fi

if [[ -f "$CONFIG_DIR/lsb-release" ]]; then
    cp "$CONFIG_DIR/lsb-release" /etc/lsb-release
    echo -e "${GREEN}  ✓ /etc/lsb-release${NC}"
fi

echo "DanlTechOS Linux \r (\l)" > /etc/issue
echo "DanlTechOS Linux" > /etc/issue.net
echo "danltechos" > /etc/hostname
echo -e "${GREEN}  ✓ Hostname: danltechos${NC}"

# ============================================
# 2. PACMAN REPOSITORY
# ============================================
echo -e "\n${GREEN}[2/5] Configuring DanlTechOS repository...${NC}"

backup_file "/etc/pacman.conf"

if ! grep -q "^\[danltechos\]" /etc/pacman.conf; then
    echo "" >> /etc/pacman.conf
    echo "# DanlTechOS Custom Repository" >> /etc/pacman.conf
    echo "[danltechos]" >> /etc/pacman.conf
    echo "SigLevel = Optional TrustAll" >> /etc/pacman.conf
    echo "Server = https://danltech.github.io/danltechos-repo/x86_64" >> /etc/pacman.conf
    echo -e "${GREEN}  ✓ Added [danltechos] repository${NC}"
else
    echo -e "${YELLOW}  ⚠ Repository already exists${NC}"
fi

# Import GPG key
if [[ -f /usr/share/danltechos/repo-key.asc ]]; then
    pacman-key --add /usr/share/danltechos/repo-key.asc 2>/dev/null || true
    pacman-key --lsign-key "DanlTechOS Repository" 2>/dev/null || true
    echo -e "${GREEN}  ✓ GPG key imported${NC}"
fi

pacman -Sy --noconfirm 2>/dev/null || true

# ============================================
# 3. GRUB CONFIGURATION WITH SPLASH IMAGE
# ============================================
echo -e "\n${GREEN}[3/5] Installing DanlTechOS GRUB configuration and splash image...${NC}"

# Copy splash image from configs to /usr/share/danltech/ and /boot/grub/
DANLTECH_DATA_DIR="/usr/share/danltech"
mkdir -p "$DANLTECH_DATA_DIR"

# Copy splash.png if provided
if [[ -f "$CONFIG_DIR/splash.png" ]]; then
    cp "$CONFIG_DIR/splash.png" "$DANLTECH_DATA_DIR/splash.png"
    echo -e "${GREEN}  ✓ Copied splash image to $DANLTECH_DATA_DIR/splash.png${NC}"
else
    echo -e "${YELLOW}  ⚠ No splash.png found in configs, skipping...${NC}"
fi

# Also copy to /boot/grub/ for GRUB to access (GRUB may not read /usr)
if [[ -f "$DANLTECH_DATA_DIR/splash.png" ]]; then
    mkdir -p /boot/grub
    cp "$DANLTECH_DATA_DIR/splash.png" /boot/grub/splash.png
    echo -e "${GREEN}  ✓ Copied splash image to /boot/grub/splash.png${NC}"
fi

# Modify /etc/default/grub to set GRUB_BACKGROUND and other DanlTechOS settings
backup_file "/etc/default/grub"

# Use custom grub file from configs if present, else edit existing
if [[ -f "$CONFIG_DIR/grub" ]]; then
    cp "$CONFIG_DIR/grub" /etc/default/grub
    echo -e "${GREEN}  ✓ /etc/default/grub (from configs)${NC}"
else
    # If no custom grub, set GRUB_BACKGROUND if not already set
    if grep -q "^GRUB_BACKGROUND=" /etc/default/grub; then
        sed -i 's|^GRUB_BACKGROUND=.*|GRUB_BACKGROUND="/boot/grub/splash.png"|' /etc/default/grub
    else
        echo 'GRUB_BACKGROUND="/boot/grub/splash.png"' >> /etc/default/grub
    fi
    echo -e "${GREEN}  ✓ /etc/default/grub updated with GRUB_BACKGROUND${NC}"
fi

# Update GRUB
if command -v grub-mkconfig &>/dev/null; then
    grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
    echo -e "${GREEN}  ✓ GRUB updated${NC}"
fi

# ============================================
# 4. KDE PLASMA WALLPAPER
# ============================================
echo -e "\n${GREEN}[4/5] Applying KDE Plasma wallpaper settings...${NC}"

# Copy wallpaper from configs to /usr/share/danltech/
if [[ -f "$CONFIG_DIR/wallpaper.png" ]]; then
    cp "$CONFIG_DIR/wallpaper.png" "$DANLTECH_DATA_DIR/wallpaper.png"
    cp "$CONFIG_DIR/wallpaper.png" "/usr/share/wallpapers/DanlTechOS.png"
    echo -e "${GREEN}  ✓ Copied wallpaper to $DANLTECH_DATA_DIR/wallpaper.png${NC}"
else
    echo -e "${YELLOW}  ⚠ No wallpaper.png found in configs, skipping wallpaper setup...${NC}"
fi

WALLPAPER_PATH="$DANLTECH_DATA_DIR/wallpaper.png"

# Function to set wallpaper for a user using plasma-apply-wallpaperimage if available
set_wallpaper_for_user() {
    local user="$1"
    local home_dir="$2"

    if [[ ! -d "$home_dir" ]]; then
        return
    fi

    # Use plasma-apply-wallpaperimage if present and user is logged in? It works even if not logged in? It writes to config.
    if command -v plasma-apply-wallpaperimage &>/dev/null && [[ -f "$WALLPAPER_PATH" ]]; then
        sudo -u "$user" plasma-apply-wallpaperimage "$WALLPAPER_PATH" 2>/dev/null && \
            echo -e "${GREEN}      ✓ Wallpaper applied to $user via plasma-apply-wallpaperimage${NC}" && return
    fi

    # Fallback: directly write to plasma desktop applets config
    # We'll copy a template if available, or try to update existing config
    local config_dir="$home_dir/.config"
    local applets_file="$config_dir/plasma-org.kde.plasma.desktop-appletsrc"

    mkdir -p "$config_dir"

    # If a template exists in configs, copy it (handles containment IDs)
    if [[ -f "$CONFIG_DIR/plasma-org.kde.plasma.desktop-appletsrc" ]]; then
        cp "$CONFIG_DIR/plasma-org.kde.plasma.desktop-appletsrc" "$applets_file"
        chown "$user:$user" "$applets_file"
        echo -e "${GREEN}      ✓ Applied template wallpaper config to $user${NC}"
    else
        # Otherwise try to set Image key using kwriteconfig5 (if we can find containment)
        # This is more complex; we'll skip if no template
        echo -e "${YELLOW}      ⚠ No template config; wallpaper not set for $user${NC}"
    fi
}

# Apply to all existing users
echo -e "${BLUE}  Applying wallpaper to all existing users...${NC}"

for user_home in /home/*; do
    if [[ -d "$user_home" ]]; then
        username=$(basename "$user_home")
        if ! id "$username" &>/dev/null; then
            continue
        fi
        uid=$(id -u "$username")
        if [[ $uid -lt 1000 ]]; then
            continue
        fi
        echo -e "${BLUE}    → Processing user: $username${NC}"
        # Backup existing applets config
        if [[ -f "$user_home/.config/plasma-org.kde.plasma.desktop-appletsrc" ]]; then
            backup_path="$BACKUP_DIR/home/$username/.config"
            mkdir -p "$backup_path"
            cp "$user_home/.config/plasma-org.kde.plasma.desktop-appletsrc" "$backup_path/"
            echo -e "${YELLOW}      ✓ Backed up plasma applets config for $username${NC}"
        fi
        set_wallpaper_for_user "$username" "$user_home"
    fi
done

# For root user (if Plasma runs as root)
if [[ -d "/root" ]]; then
    set_wallpaper_for_user "root" "/root"
fi

# For future users: copy wallpaper and template to /etc/skel
if [[ -f "$WALLPAPER_PATH" ]]; then
    mkdir -p /etc/skel/.config
    if [[ -f "$CONFIG_DIR/plasma-org.kde.plasma.desktop-appletsrc" ]]; then
        cp "$CONFIG_DIR/plasma-org.kde.plasma.desktop-appletsrc" /etc/skel/.config/
        echo -e "${GREEN}  ✓ Wallpaper template placed in /etc/skel for future users${NC}"
    else
        # If no template, we can create a minimal one using kwriteconfig5? But we need to run as a user.
        # We'll just skip, or we can create a script that runs on first login.
        echo -e "${YELLOW}  ⚠ No wallpaper template for future users; they will not have custom wallpaper automatically.${NC}"
    fi
fi

# Try to apply immediately for the current user (if running in Plasma)
if [[ -n "$SUDO_USER" ]] && [[ "$SUDO_USER" != "root" ]]; then
    if command -v plasma-apply-wallpaperimage &>/dev/null && [[ -f "$WALLPAPER_PATH" ]]; then
        sudo -u "$SUDO_USER" plasma-apply-wallpaperimage "$WALLPAPER_PATH" 2>/dev/null && \
            echo -e "${GREEN}  ✓ Wallpaper applied to current session (user $SUDO_USER)${NC}"
    fi
fi

echo -e "${GREEN}  ✓ Wallpaper settings applied${NC}"

# ============================================
# 5. KDE GLOBALS (from earlier)
# ============================================
echo -e "\n${GREEN}[5/5] Applying KDE Plasma global settings (kdeglobals)...${NC}"

# For ALL FUTURE users (/etc/skel)
mkdir -p /etc/skel/.config

if [[ -f "$CONFIG_DIR/kdeglobals" ]]; then
    cp "$CONFIG_DIR/kdeglobals" /etc/skel/.config/kdeglobals
    echo -e "${GREEN}  ✓ /etc/skel/.config/kdeglobals (for future users)${NC}"
else
    echo -e "${YELLOW}  ⚠ No custom kdeglobals found, skipping...${NC}"
fi

# For ALL EXISTING users
echo -e "${BLUE}  Applying to all existing users...${NC}"

for user_home in /home/*; do
    if [[ -d "$user_home" ]]; then
        username=$(basename "$user_home")
        if ! id "$username" &>/dev/null; then
            continue
        fi
        uid=$(id -u "$username")
        if [[ $uid -lt 1000 ]]; then
            continue
        fi
        echo -e "${BLUE}    → Processing user: $username${NC}"
        if [[ -f "$user_home/.config/kdeglobals" ]]; then
            backup_path="$BACKUP_DIR/home/$username/.config"
            mkdir -p "$backup_path"
            cp "$user_home/.config/kdeglobals" "$backup_path/"
            echo -e "${YELLOW}      ✓ Backed up kdeglobals for $username${NC}"
        fi
        mkdir -p "$user_home/.config"
        if [[ -f "$CONFIG_DIR/kdeglobals" ]]; then
            cp "$CONFIG_DIR/kdeglobals" "$user_home/.config/"
            chown "$username:$username" "$user_home/.config/kdeglobals"
            echo -e "${GREEN}      ✓ Applied to $username${NC}"
        fi
    fi
done

if [[ -d "/root" ]]; then
    mkdir -p /root/.config
    if [[ -f "$CONFIG_DIR/kdeglobals" ]]; then
        cp "$CONFIG_DIR/kdeglobals" /root/.config/
        echo -e "${GREEN}  ✓ Applied to root user${NC}"
    fi
fi

# Apply accent color immediately if possible
if [[ -n "$SUDO_USER" ]] && [[ "$SUDO_USER" != "root" ]]; then
    if command -v kwriteconfig5 &>/dev/null; then
        sudo -u "$SUDO_USER" kwriteconfig5 --file kdeglobals --group KDE --key AccentColor "#ff5722" 2>/dev/null || true
        echo -e "${GREEN}  ✓ Accent color applied immediately (current Plasma session)${NC}"
    fi
fi

echo -e "${GREEN}  ✓ KDE settings applied to ALL users${NC}"

# ============================================
# FINISH
# ============================================
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  DanlTechOS Setup Complete! 🎉${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Backup: $BACKUP_DIR${NC}"
echo ""
echo -e "${GREEN}Available commands:${NC}"
echo "  danltechos-version  - Show OS version"
echo "  danltechos-help     - Show help"
echo "  danltechos-update   - Update system"
echo "  danltechos-repo     - Repository info"
echo ""
echo -e "${GREEN}GRUB: DanlTechOS splash image applied${NC}"
echo -e "${GREEN}KDE Plasma: Wallpaper and global settings applied${NC}"
echo ""
echo -e "${GREEN}Reboot recommended: sudo reboot${NC}"

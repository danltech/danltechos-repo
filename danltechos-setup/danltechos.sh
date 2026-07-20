#!/bin/bash
# danltechos-setup - Transform EndeavourOS into DanlTechOS

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
# CONFIGURATION DIRECTORY (vom Package)
# ============================================
CONFIG_DIR="/usr/share/danltechos/configs"

if [[ ! -d "$CONFIG_DIR" ]]; then
    echo -e "${RED}Error: Config directory not found!${NC}"
    echo "Please reinstall danltechos-setup package."
    exit 1
fi

echo -e "${GREEN}Using configs from: $CONFIG_DIR${NC}"

# ============================================
# 1. SYSTEM FILES (aus configs)
# ============================================
echo -e "\n${GREEN}[1/4] Installing DanlTechOS system files...${NC}"

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
echo -e "\n${GREEN}[2/4] Configuring DanlTechOS repository...${NC}"

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
# 3. GRUB CONFIGURATION (aus configs)
# ============================================
echo -e "\n${GREEN}[3/4] Installing DanlTechOS GRUB configuration...${NC}"

backup_file "/etc/default/grub"

if [[ -f "$CONFIG_DIR/grub" ]]; then
    cp "$CONFIG_DIR/grub" /etc/default/grub
    echo -e "${GREEN}  ✓ /etc/default/grub (from configs)${NC}"
else
    echo -e "${YELLOW}  ⚠ No custom grub config found, skipping...${NC}"
fi

# Update GRUB
if command -v grub-mkconfig &>/dev/null; then
    grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
    echo -e "${GREEN}  ✓ GRUB updated${NC}"
fi

# ============================================
# 4. KDE PLASMA CONFIGURATION (für ALLE User)
# ============================================
echo -e "\n${GREEN}[4/4] Applying KDE Plasma settings for ALL users...${NC}"

# For ALL FUTURE users (/etc/skel)
mkdir -p /etc/skel/.config

if [[ -f "$CONFIG_DIR/kdeglobals" ]]; then
    cp "$CONFIG_DIR/kdeglobals" /etc/skel/.config/kdeglobals
    echo -e "${GREEN}  ✓ /etc/skel/.config/kdeglobals (for future users)${NC}"
else
    echo -e "${YELLOW}  ⚠ No custom kdeglobals found, skipping...${NC}"
fi

# For ALL EXISTING users (including current user)
echo -e "${BLUE}  Applying to all existing users...${NC}"

# Get all real users (UID >= 1000, not system users)
for user_home in /home/*; do
    if [[ -d "$user_home" ]]; then
        username=$(basename "$user_home")

        # Skip if user doesn't exist in passwd (shouldn't happen)
        if ! id "$username" &>/dev/null; then
            continue
        fi

        # Skip system users (UID < 1000)
        uid=$(id -u "$username")
        if [[ $uid -lt 1000 ]]; then
            continue
        fi

        echo -e "${BLUE}    → Processing user: $username${NC}"

        # Backup existing kdeglobals
        if [[ -f "$user_home/.config/kdeglobals" ]]; then
            backup_path="$BACKUP_DIR/home/$username/.config"
            mkdir -p "$backup_path"
            cp "$user_home/.config/kdeglobals" "$backup_path/"
            echo -e "${YELLOW}      ✓ Backed up kdeglobals for $username${NC}"
        fi

        # Create config directory if not exists
        mkdir -p "$user_home/.config"

        # Copy new kdeglobals
        if [[ -f "$CONFIG_DIR/kdeglobals" ]]; then
            cp "$CONFIG_DIR/kdeglobals" "$user_home/.config/"
            chown "$username:$username" "$user_home/.config/kdeglobals"
            echo -e "${GREEN}      ✓ Applied to $username${NC}"
        fi
    fi
done

# For root user (if KDE is run as root)
if [[ -d "/root/.config" ]] || [[ -d "/root" ]]; then
    mkdir -p /root/.config
    if [[ -f "$CONFIG_DIR/kdeglobals" ]]; then
        cp "$CONFIG_DIR/kdeglobals" /root/.config/
        echo -e "${GREEN}  ✓ Applied to root user${NC}"
    fi
fi

# Try to apply immediately for the current user (if running in Plasma)
if [[ -n "$SUDO_USER" ]] && [[ "$SUDO_USER" != "root" ]]; then
    if command -v kwriteconfig5 &>/dev/null; then
        sudo -u "$SUDO_USER" kwriteconfig5 --file kdeglobals --group KDE --key AccentColor "#ff5722" 2>/dev/null || true
        echo -e "${GREEN}  ✓ Settings applied immediately (current Plasma session)${NC}"
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
echo -e "${GREEN}GRUB: DanlTechOS config applied${NC}"
echo -e "${GREEN}KDE Plasma: Settings applied${NC}"
echo ""
echo -e "${GREEN}Reboot recommended: sudo reboot${NC}"

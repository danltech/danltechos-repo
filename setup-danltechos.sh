#!/bin/bash
# setup-danltechos.sh - Transform EndeavourOS into DanlTechOS
# Usage: sudo ./setup-danltechos.sh

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  DanlTechOS Setup Script v1.0${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root!${NC}"
   echo "Please run: sudo ./setup-danltechos.sh"
   exit 1
fi

# Define backup directory with timestamp
BACKUP_DIR="/root/danltechos-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo -e "${YELLOW}Backups will be saved to: $BACKUP_DIR${NC}"

# ============================================
# 1. BACKUP ORIGINAL FILES
# ============================================
echo -e "\n${GREEN}[1/6] Backing up original files...${NC}"

backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup_path="$BACKUP_DIR$(dirname "$file")"
        mkdir -p "$backup_path"
        cp -v "$file" "$backup_path/"
        echo -e "${GREEN}  ✓ Backed up: $file${NC}"
    else
        echo -e "${YELLOW}  ⚠ File not found (skipping): $file${NC}"
    fi
}

backup_file "/etc/os-release"
backup_file "/etc/lsb-release"
backup_file "/etc/issue"
backup_file "/etc/issue.net"
backup_file "/etc/hostname"
backup_file "/etc/pacman.conf"
backup_file "/etc/pacman.d/mirrorlist"

# ============================================
# 2. OVERWRITE SYSTEM FILES WITH DANLTECHOS VERSION
# ============================================
echo -e "\n${GREEN}[2/6] Installing DanlTechOS system files...${NC}"

# Create directory for our custom files
mkdir -p /usr/share/danltechos

# os-release
cat > /etc/os-release << 'EOF'
NAME="DanlTechOS"
PRETTY_NAME="DanlTechOS"
ID="danltechos"
ID_LIKE="arch"
BUILD_ID=rolling
ANSI_COLOR="38;2;23;147;209"
HOME_URL="https://github.com/deutschich"
DOCUMENTATION_URL="https://github.com/deutschich"
SUPPORT_URL="https://github.com/deutschich"
BUG_REPORT_URL="https://github.com/deutschich"
PRIVACY_POLICY_URL="https://github.com/deutschich"
LOGO="danltechos"
EOF
echo -e "${GREEN}  ✓ Created /etc/os-release${NC}"

# lsb-release
cat > /etc/lsb-release << 'EOF'
LSB_VERSION=1.4
DISTRIB_ID=DanlTechOS
DISTRIB_RELEASE=rolling
DISTRIB_DESCRIPTION="DanlTechOS Linux"
EOF
echo -e "${GREEN}  ✓ Created /etc/lsb-release${NC}"

# issue (login banner)
cat > /etc/issue << 'EOF'
DanlTechOS Linux \r (\l)

EOF
echo -e "${GREEN}  ✓ Created /etc/issue${NC}"

# issue.net (for SSH)
cat > /etc/issue.net << 'EOF'
DanlTechOS Linux

EOF
echo -e "${GREEN}  ✓ Created /etc/issue.net${NC}"

# hostname
echo "danltechos" > /etc/hostname
echo -e "${GREEN}  ✓ Set hostname to: danltechos${NC}"

# ============================================
# 3. SETUP CUSTOM REPOSITORY
# ============================================
echo -e "\n${GREEN}[3/6] Setting up DanlTechOS custom repository...${NC}"

# Generate GPG key for repository signing (if not exists)
if [[ ! -f /root/danltechos-repo-key.asc ]]; then
    echo -e "${YELLOW}  Generating GPG key for repository signing...${NC}"

    # Create GPG key batch config
    cat > /tmp/gpg-batch << EOF
%echo Generating DanlTechOS repository signing key
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: DanlTechOS Repository
Name-Email: danltechos@localhost
Expire-Date: 0
%commit
%echo Done
EOF

    gpg --batch --generate-key /tmp/gpg-batch
    rm /tmp/gpg-batch

    # Export public key
    gpg --export --armor "DanlTechOS Repository" > /root/danltechos-repo-key.asc
    echo -e "${GREEN}  ✓ GPG key generated and exported to /root/danltechos-repo-key.asc${NC}"
else
    echo -e "${GREEN}  ✓ GPG key already exists${NC}"
fi

# Add repository to pacman.conf
if ! grep -q "^\[danltechos\]" /etc/pacman.conf; then
    echo -e "\n# DanlTechOS Custom Repository" >> /etc/pacman.conf
    echo "[danltechos]" >> /etc/pacman.conf
    echo "SigLevel = Optional TrustAll" >> /etc/pacman.conf
    echo "Server = https://danltechos.github.io/danltechos-repo/x86_64" >> /etc/pacman.conf
    echo -e "${GREEN}  ✓ Added [danltechos] repository to /etc/pacman.conf${NC}"
else
    echo -e "${YELLOW}  ⚠ [danltechos] repository already exists in pacman.conf${NC}"
fi

# Import GPG key to pacman keyring
pacman-key --add /root/danltechos-repo-key.asc 2>/dev/null || true
pacman-key --lsign-key "DanlTechOS Repository" 2>/dev/null || true
echo -e "${GREEN}  ✓ GPG key imported to pacman keyring${NC}"

# ============================================
# 4. INSTALL BASE DANLTECHOS PACKAGES
# ============================================
echo -e "\n${GREEN}[4/6] Installing DanlTechOS base packages...${NC}"

# Update package database
pacman -Sy --noconfirm

# List of base packages to install
BASE_PACKAGES=(
    "wget"
    "git"
    "base-devel"
    "yay"
)

for pkg in "${BASE_PACKAGES[@]}"; do
    if pacman -Qi "$pkg" &>/dev/null; then
        echo -e "${YELLOW}  ⚠ Package already installed: $pkg${NC}"
    else
        echo -e "${GREEN}  ✓ Installing: $pkg${NC}"
        pacman -S --noconfirm "$pkg"
    fi
done

# ============================================
# 5. CUSTOMIZE GRUB (optional)
# ============================================
echo -e "\n${GREEN}[5/6] Customizing GRUB bootloader...${NC}"

if [[ -f /etc/default/grub ]]; then
    backup_file "/etc/default/grub"

    # Replace GRUB_DISTRIBUTOR
    sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="DanlTechOS"/' /etc/default/grub

    # Update GRUB
    if command -v grub-mkconfig &>/dev/null; then
        grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
        echo -e "${GREEN}  ✓ GRUB updated${NC}"
    fi
fi

# ============================================
# 6. CREATE DANLTECHOS WELCOME SCREEN
# ============================================
echo -e "\n${GREEN}[6/6] Creating DanlTechOS welcome message...${NC}"

# Create motd (message of the day)
cat > /etc/motd << 'EOF'
========================================
  Welcome to DanlTechOS Linux! 🚀
========================================

  "Make it work, make it right, make it fast."

  📦 Repository: https://danltechos.github.io/danltechos-repo
  📖 Docs: https://danltechos.github.io/docs
  💬 Support: https://danltechos.github.io/support

  System information:
  - OS: DanlTechOS (based on EndeavourOS/Arch)
  - Kernel: $(uname -r)
  - Architecture: $(uname -m)

  Type 'danltechos-help' for available commands.

========================================
EOF

# Create helper script
cat > /usr/local/bin/danltechos-help << 'EOF'
#!/bin/bash
echo "========================================"
echo "  DanlTechOS Help Commands"
echo "========================================"
echo ""
echo "  danltechos-version  - Show OS version"
echo "  danltechos-update   - Update system (pacman -Syu)"
echo "  danltechos-repo     - Show repository info"
echo ""
echo "========================================"
EOF
chmod +x /usr/local/bin/danltechos-help

# Create version display script
cat > /usr/local/bin/danltechos-version << 'EOF'
#!/bin/bash
cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"'
EOF
chmod +x /usr/local/bin/danltechos-version

# Create logo display script
cat > /usr/local/bin/danltechos-logo << 'EOF'
#!/bin/bash
cat /usr/share/danltechos/logo.txt
EOF
chmod +x /usr/local/bin/danltechos-logo

# Create repo info script
cat > /usr/local/bin/danltechos-repo << 'EOF'
#!/bin/bash
echo "DanlTechOS Custom Repository"
echo "============================="
echo "Server: https://danltechos.github.io/danltechos-repo/x86_64"
echo ""
echo "To add packages:"
echo "  1. Build package with makepkg"
echo "  2. Add to repo: repo-add /path/to/danltechos.db.tar.gz *.pkg.tar.zst"
echo "  3. Upload to GitHub Pages"
echo ""
echo "GPG Key: /root/danltechos-repo-key.asc"
EOF
chmod +x /usr/local/bin/danltechos-repo

echo -e "${GREEN}  ✓ Created danltechos-help, danltechos-version, danltechos-logo, danltechos-repo${NC}"

# ============================================
# FINALIZE
# ============================================
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  DanlTechOS Setup Complete! 🎉${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n${YELLOW}Backups saved to: $BACKUP_DIR${NC}"
echo -e "${YELLOW}GPG key saved to: /root/danltechos-repo-key.asc${NC}"
echo -e "${YELLOW}Repository added to: /etc/pacman.conf${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "  1. Reboot to apply changes: sudo reboot"
echo "  2. Create your own packages and add them to the repo"
echo "  3. Upload packages to GitHub Pages (see danltechos-repo command)"
echo ""
echo -e "${GREEN}Available commands:${NC}"
echo "  danltechos-version  - Show OS version"
echo "  danltechos-logo     - Show DanlTechOS logo"
echo "  danltechos-help     - Show help"
echo "  danltechos-repo     - Repository info"

#!/bin/bash
# setup-repo.sh - One-time repository setup for DanlTechOS
# Run this ONCE to initialize your GitHub Pages repository

set -e

echo "========================================"
echo "  DanlTechOS Repository Setup"
echo "========================================"

# ============================================
# CONFIGURATION - CHANGE THESE!
# ============================================
ORG_NAME="danltech"                    # Your GitHub organization name
REPO_NAME="danltechos-repo"            # Repository name
REPO_URL="https://github.com/$ORG_NAME/$REPO_NAME.git"
PAGES_URL="https://$ORG_NAME.github.io/$REPO_NAME"

echo "Organization: $ORG_NAME"
echo "Repository: $REPO_NAME"
echo "Pages URL: $PAGES_URL"
echo ""

# ============================================
# CHECK PREREQUISITES
# ============================================
if ! command -v gh &>/dev/null; then
    echo "Installing GitHub CLI..."
    sudo pacman -S --noconfirm github-cli
fi

if ! gh auth status &>/dev/null; then
    echo "Please login to GitHub:"
    gh auth login
fi

# ============================================
# CREATE REPOSITORY ON GITHUB
# ============================================
echo "Creating repository on GitHub..."

# Check if repo exists, create if not
if ! gh repo view "$ORG_NAME/$REPO_NAME" &>/dev/null; then
    gh repo create "$ORG_NAME/$REPO_NAME" --public --description "DanlTechOS Package Repository" --clone
else
    echo "Repository already exists, cloning..."
fi

# ============================================
# SETUP LOCAL REPO
# ============================================
if [[ -d "$REPO_NAME" ]]; then
    cd "$REPO_NAME"
    git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true
else
    git clone "$REPO_URL"
    cd "$REPO_NAME"
fi

# Create x86_64 directory
mkdir -p x86_64

# ============================================
# GENERATE GPG KEY (if not exists)
# ============================================
if [[ ! -f danltechos-repo-key.asc ]]; then
    echo "Generating GPG key for repository signing..."

    cat > /tmp/gpg-batch << EOF
%echo Generating DanlTechOS repository signing key
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: DanlTechOS Repository
Name-Email: danltechos@$ORG_NAME
Expire-Date: 0
%commit
%echo Done
EOF

    gpg --batch --generate-key /tmp/gpg-batch 2>/dev/null
    rm /tmp/gpg-batch

    # Get the key ID and export
    KEY_ID=$(gpg --list-keys --with-colons "DanlTechOS Repository" | grep "^pub" | cut -d: -f5 | head -1)
    gpg --export --armor "$KEY_ID" > danltechos-repo-key.asc
    echo "✓ GPG key generated: danltechos-repo-key.asc"
fi

# ============================================
# CREATE REPOSITORY FILES
# ============================================
cat > README.md << 'EOF'
# DanlTechOS Package Repository

Official package repository for DanlTechOS.

## Quick Install

```bash
curl -sL https://danltech.github.io/danltechos-repo/install.sh | bash
```

## Manual Setup

Add to `/etc/pacman.conf`:

```ini
[danltechos]
SigLevel = Optional TrustAll
Server = https://danltech.github.io/danltechos-repo/x86_64
```

Then:

```bash
sudo pacman -Sy
sudo pacman -S danltechos-setup
```

## GPG Key

```bash
curl -L https://danltech.github.io/danltechos-repo/danltechos-repo-key.asc | sudo pacman-key --add -
sudo pacman-key --lsign-key "DanlTechOS Repository"
```

## Package List

- `danltechos-setup` - Transforms EndeavourOS into DanlTechOS
EOF

# Create install script for users
cat > install.sh << 'EOF'
#!/bin/bash
# install.sh - One-command install for DanlTechOS

set -e

echo "========================================"
echo "  DanlTechOS Installer"
echo "========================================"

# Add repository
echo "[danltechos]" | sudo tee -a /etc/pacman.conf > /dev/null
echo "SigLevel = Optional TrustAll" | sudo tee -a /etc/pacman.conf > /dev/null
echo "Server = https://danltech.github.io/danltechos-repo/x86_64" | sudo tee -a /etc/pacman.conf > /dev/null

# Update and install
sudo pacman -Sy --noconfirm
sudo pacman -S --noconfirm danltechos-setup

echo ""
echo "✅ DanlTechOS installed successfully!"
echo "Run: danltechos-help for available commands"
EOF
chmod +x install.sh

# ============================================
# CREATE INITIAL REPO DATABASE
# ============================================
cd x86_64
repo-add danltechos.db.tar.gz 2>/dev/null || true
cd ..

# ============================================
# PUSH TO GITHUB
# ============================================
git add .
git commit -m "Initial repository setup"
git push origin main 2>/dev/null || git push origin master 2>/dev/null

echo ""
echo "========================================"
echo "  Repository setup complete! 🎉"
echo "========================================"
echo ""
echo "Repository URL: $PAGES_URL"
echo "GPG Key: danltechos-repo-key.asc (SAVE THIS FILE!)"
echo ""
echo "Next steps:"
echo "1. Create the danltechos-setup package"
echo "2. Build and push: ./build-and-push.sh"
echo ""
echo "Users can install with:"
echo "  curl -sL $PAGES_URL/install.sh | bash"

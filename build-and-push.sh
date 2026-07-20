#!/bin/bash
# build-and-push.sh - Build danltechos-setup and publish to repository

set -e

echo "========================================"
echo "  Building danltechos-setup package"
echo "========================================"

# ============================================
# BUILD
# ============================================
cd danltechos-setup

# Increment release number
if [[ -f .release ]]; then
    RELEASE=$(cat .release)
    RELEASE=$((RELEASE + 1))
else
    RELEASE=1
fi
echo $RELEASE > .release

# Update PKGBUILD with new release number
sed -i "s/^pkgrel=.*/pkgrel=$RELEASE/" PKGBUILD

# Build
makepkg -si --noconfirm

# Get the built package file
PKG_FILE=$(ls *.pkg.tar.zst | head -1)

if [[ -z "$PKG_FILE" ]]; then
    echo "Error: No package built!"
    exit 1
fi

echo "✓ Package built: $PKG_FILE"

# ============================================
# DEPLOY TO REPOSITORY
# ============================================
REPO_DIR="../danltechos-repo"

if [[ ! -d "$REPO_DIR" ]]; then
    echo "Repository not found at $REPO_DIR"
    echo "Running setup-repo.sh first..."
    cd ..
    ./setup-repo.sh
    cd danltechos-setup
    REPO_DIR="../danltechos-repo"
fi

# Copy package
cp "$PKG_FILE" "$REPO_DIR/x86_64/"

# Update repository database
cd "$REPO_DIR"
repo-add x86_64/danltechos.db.tar.gz x86_64/*.pkg.tar.zst

# Push to GitHub
git add .
git commit -m "Update danltechos-setup: release $RELEASE"
git push

echo ""
echo "========================================"
echo "  Deployed successfully! 🚀"
echo "========================================"
echo ""
echo "Repository URL: https://danltech.github.io/danltechos-repo"
echo "Package: danltechos-setup (release $RELEASE)"
echo ""
echo "Users can install with:"
echo "  sudo pacman -S danltechos-setup"
